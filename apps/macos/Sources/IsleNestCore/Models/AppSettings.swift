import Foundation

public enum IslandStyle: String, Codable, CaseIterable, Sendable {
    case automatic
    case notch
    case floating
}

public enum IslandTrigger: String, Codable, CaseIterable, Sendable {
    case click
    case hover
}

public enum FloatingAnchor: String, Codable, CaseIterable, Sendable {
    case left
    case center
    case right
}

public enum CaptureOutputMode: String, Codable, CaseIterable, Sendable {
    case preview
    case autoCopy
}

public enum IslandThemePreset: String, Codable, CaseIterable, Sendable {
    case moss
    case dusk
    case tide
    case aurora
    case ember
}

public enum IslandAppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum WorkspaceBackdropStyle: String, Codable, CaseIterable, Sendable {
    case clear
    case frosted
    case dense
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var style: IslandStyle
    public var trigger: IslandTrigger
    public var floatingAnchor: FloatingAnchor
    public var captureOutputMode: CaptureOutputMode
    public var theme: IslandThemePreset
    public var appearance: IslandAppearanceMode
    public var workspaceBackdrop: WorkspaceBackdropStyle
    public var displayIslandWidths: [String: Double]
    public var hoverExpandDelay: TimeInterval
    public var hoverCollapseDelay: TimeInterval
    public var onboardingCompleted: Bool
    public var screenshotDirectoryPath: String?
    public var recordingDirectoryPath: String?
    public var screenshotSaveWithoutPrompt: Bool

    public init(
        style: IslandStyle = .automatic,
        trigger: IslandTrigger = .click,
        floatingAnchor: FloatingAnchor = .center,
        captureOutputMode: CaptureOutputMode = .preview,
        theme: IslandThemePreset = .moss,
        appearance: IslandAppearanceMode = .system,
        workspaceBackdrop: WorkspaceBackdropStyle = .frosted,
        displayIslandWidths: [String: Double] = [:],
        hoverExpandDelay: TimeInterval = 0.35,
        hoverCollapseDelay: TimeInterval = 0.5,
        onboardingCompleted: Bool = false,
        screenshotDirectoryPath: String? = nil,
        recordingDirectoryPath: String? = nil,
        screenshotSaveWithoutPrompt: Bool = false
    ) {
        self.style = style
        self.trigger = trigger
        self.floatingAnchor = floatingAnchor
        self.captureOutputMode = captureOutputMode
        self.theme = theme
        self.appearance = appearance
        self.workspaceBackdrop = workspaceBackdrop
        self.displayIslandWidths = displayIslandWidths
        self.hoverExpandDelay = hoverExpandDelay
        self.hoverCollapseDelay = hoverCollapseDelay
        self.onboardingCompleted = onboardingCompleted
        self.screenshotDirectoryPath = screenshotDirectoryPath
        self.recordingDirectoryPath = recordingDirectoryPath
        self.screenshotSaveWithoutPrompt = screenshotSaveWithoutPrompt
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case trigger
        case floatingAnchor
        case captureOutputMode
        case theme
        case appearance
        case workspaceBackdrop
        case displayIslandWidths
        case hoverExpandDelay
        case hoverCollapseDelay
        case onboardingCompleted
        case screenshotDirectoryPath
        case recordingDirectoryPath
        case screenshotSaveWithoutPrompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decodeIfPresent(IslandStyle.self, forKey: .style) ?? .automatic
        trigger = try container.decodeIfPresent(IslandTrigger.self, forKey: .trigger) ?? .click
        floatingAnchor = try container.decodeIfPresent(FloatingAnchor.self, forKey: .floatingAnchor) ?? .center
        captureOutputMode = try container.decodeIfPresent(CaptureOutputMode.self, forKey: .captureOutputMode) ?? .preview
        theme = try container.decodeIfPresent(IslandThemePreset.self, forKey: .theme) ?? .moss
        appearance = try container.decodeIfPresent(IslandAppearanceMode.self, forKey: .appearance) ?? .system
        workspaceBackdrop = try container.decodeIfPresent(WorkspaceBackdropStyle.self, forKey: .workspaceBackdrop) ?? .frosted
        displayIslandWidths = try container.decodeIfPresent([String: Double].self, forKey: .displayIslandWidths) ?? [:]
        hoverExpandDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .hoverExpandDelay) ?? 0.35
        hoverCollapseDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .hoverCollapseDelay) ?? 0.5
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        screenshotDirectoryPath = try container.decodeIfPresent(String.self, forKey: .screenshotDirectoryPath)
        recordingDirectoryPath = try container.decodeIfPresent(String.self, forKey: .recordingDirectoryPath)
        screenshotSaveWithoutPrompt = try container.decodeIfPresent(Bool.self, forKey: .screenshotSaveWithoutPrompt) ?? false
    }
}
