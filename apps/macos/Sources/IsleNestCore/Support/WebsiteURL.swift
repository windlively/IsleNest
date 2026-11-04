import Foundation

public enum WebsiteURL {
    public static func normalize(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let schemeRange = trimmed.range(
            of: "^[A-Za-z][A-Za-z0-9+.-]*:",
            options: .regularExpression
        )
        var candidate = "https://\(trimmed)"
        if let schemeRange {
            let remainder = trimmed[schemeRange.upperBound...]
            let isPortLike = remainder.first?.isNumber == true
            if !isPortLike {
                candidate = trimmed
            }
        }

        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    public static func defaultTitle(for url: URL) -> String {
        guard var host = url.host else {
            return url.absoluteString
        }
        if host.lowercased().hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }
}
