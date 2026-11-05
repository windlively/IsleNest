import Darwin
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpuUsage = 0.0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = 0
    @Published private(set) var diskName = "启动磁盘"
    @Published private(set) var diskUsed: UInt64 = 0
    @Published private(set) var diskTotal: UInt64 = 0
    @Published private(set) var downloadBytesPerSecond = 0.0
    @Published private(set) var uploadBytesPerSecond = 0.0

    private var timer: Timer?
    private var previousCPUTicks: (
        user: UInt64,
        system: UInt64,
        idle: UInt64,
        nice: UInt64
    )?
    private var previousNetwork: (received: UInt64, sent: UInt64, date: Date)?

    var memoryUsage: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0
    }

    var diskUsage: Double {
        diskTotal > 0 ? Double(diskUsed) / Double(diskTotal) : 0
    }

    var diskFree: UInt64 {
        diskTotal > diskUsed ? diskTotal - diskUsed : 0
    }

    func start() {
        guard timer == nil else {
            return
        }
        previousCPUTicks = nil
        previousNetwork = nil
        sample()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousCPUTicks = nil
        previousNetwork = nil
        downloadBytesPerSecond = 0
        uploadBytesPerSecond = 0
    }

    private func sample() {
        updateCPU()
        updateMemory()
        updateDisk()
        updateNetwork()
    }

    private func updateCPU() {
        guard let ticks = currentCPUTicks() else {
            return
        }
        defer { previousCPUTicks = ticks }
        guard let previous = previousCPUTicks else {
            return
        }

        let previousTotal = previous.user + previous.system + previous.idle + previous.nice
        let total = ticks.user + ticks.system + ticks.idle + ticks.nice
        let delta = total >= previousTotal ? total - previousTotal : 0
        guard delta > 0 else {
            return
        }
        let busy = (ticks.user - previous.user)
            + (ticks.system - previous.system)
            + (ticks.nice - previous.nice)
        cpuUsage = min(1, max(0, Double(busy) / Double(delta)))
    }

    private func currentCPUTicks() -> (
        user: UInt64,
        system: UInt64,
        idle: UInt64,
        nice: UInt64
    )? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride
                / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }
        return (
            UInt64(info.cpu_ticks.0),
            UInt64(info.cpu_ticks.1),
            UInt64(info.cpu_ticks.2),
            UInt64(info.cpu_ticks.3)
        )
    }

    private func updateMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride
                / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return
        }
        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        memoryUsed = active + wired + compressed
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }

    private func updateDisk() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        if let name = values?.volumeName, !name.isEmpty {
            diskName = name
        }
        if let total = values?.volumeTotalCapacity {
            diskTotal = UInt64(total)
        }
        if let available = values?.volumeAvailableCapacityForImportantUsage {
            let free = UInt64(max(0, available))
            diskUsed = diskTotal > free ? diskTotal - free : 0
        }
    }

    private func updateNetwork() {
        guard let counters = currentNetworkCounters() else {
            return
        }
        let now = Date()
        defer {
            previousNetwork = (counters.received, counters.sent, now)
        }
        guard let previous = previousNetwork else {
            return
        }
        let elapsed = now.timeIntervalSince(previous.date)
        guard elapsed > 0.1 else {
            return
        }
        let received = counters.received >= previous.received
            ? counters.received - previous.received
            : 0
        let sent = counters.sent >= previous.sent
            ? counters.sent - previous.sent
            : 0
        downloadBytesPerSecond = Double(received) / elapsed
        uploadBytesPerSecond = Double(sent) / elapsed
    }

    private func currentNetworkCounters() -> (received: UInt64, sent: UInt64)? {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let first = addressList else {
            return nil
        }
        defer { freeifaddrs(addressList) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }
            let flags = interface.pointee.ifa_flags
            let name = String(cString: interface.pointee.ifa_name)
            guard name.hasPrefix("en"),
                  (flags & UInt32(IFF_UP)) != 0,
                  (flags & UInt32(IFF_LOOPBACK)) == 0,
                  let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = interface.pointee.ifa_data else {
                continue
            }
            let statistics = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(statistics.ifi_ibytes)
            sent += UInt64(statistics.ifi_obytes)
        }
        return (received, sent)
    }
}
