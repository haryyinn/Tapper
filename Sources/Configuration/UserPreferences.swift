/// Diagnostic logging severity (`DATA_MODELS` §3.15).
public enum LogLevel: String, Sendable, Equatable, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
    case critical
}

/// Configurable application settings that persist across launches
/// (`DATA_MODELS` §13.6).
///
/// Owned by the Configuration system (§13.9). Immutable once loaded; changing a
/// preference produces a new value that is validated and persisted.
///
/// - Note: ``launchAtLogin`` is *persisted only*. Registering an actual login
///   item is System Integration work and is not performed here.
public struct UserPreferences: Sendable, Equatable, Codable {

    /// Whether diagnostics collection is enabled.
    public let diagnosticsEnabled: Bool

    /// The diagnostic logging severity.
    public let loggingLevel: LogLevel

    /// Whether Tapper should launch at login (persisted preference only).
    public let launchAtLogin: Bool

    /// Whether automatic updates are enabled (persisted preference only).
    public let automaticUpdates: Bool

    /// Creates user preferences.
    public init(
        diagnosticsEnabled: Bool,
        loggingLevel: LogLevel,
        launchAtLogin: Bool,
        automaticUpdates: Bool
    ) {
        self.diagnosticsEnabled = diagnosticsEnabled
        self.loggingLevel = loggingLevel
        self.launchAtLogin = launchAtLogin
        self.automaticUpdates = automaticUpdates
    }

    /// The default preferences restored on first launch or after corruption
    /// (`TRD` §8, `ARCHITECTURE` §11).
    ///
    /// Launch at Login is off by default (`DECISIONS` ADR-008).
    public static let defaults = UserPreferences(
        diagnosticsEnabled: false,
        loggingLevel: .info,
        launchAtLogin: false,
        automaticUpdates: false
    )
}
