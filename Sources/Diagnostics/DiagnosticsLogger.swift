import Configuration
import Foundation
import os

/// Records diagnostic events to an in-memory log and to the unified system log
/// (`ARCHITECTURE` §4.8, `API_REFERENCE` §8).
///
/// Logging is **best effort and observational only**: it never throws, never
/// reports failure to the caller, and never influences recognition, execution,
/// or configuration (`DATA_MODELS` §11.13, `ALGORITHM` §27.11).
///
/// The logger *reads* the diagnostics preference owned by Configuration; it
/// never writes configuration. When diagnostics are disabled, events below the
/// error threshold are dropped, but errors are always recorded so failures
/// remain traceable (`TRD` FR-DG-002).
///
/// Messages must contain no raw microphone data, personally identifiable
/// information, or secrets (`IMPLEMENTATION_RULES` §Logging).
public struct DiagnosticsLogger {

    private let log: DiagnosticsLog
    private let subsystem: String
    private let diagnosticsEnabled: Bool
    private let minimumLevel: LogLevel

    /// Creates a logger.
    ///
    /// - Parameters:
    ///   - log: The in-memory record store to append to.
    ///   - diagnosticsEnabled: The user's diagnostics preference (read-only).
    ///   - minimumLevel: The minimum severity recorded when diagnostics are
    ///     enabled.
    ///   - subsystem: The OSLog subsystem identifier.
    public init(
        log: DiagnosticsLog,
        diagnosticsEnabled: Bool,
        minimumLevel: LogLevel = .info,
        subsystem: String = "com.tapper.diagnostics"
    ) {
        self.log = log
        self.diagnosticsEnabled = diagnosticsEnabled
        self.minimumLevel = minimumLevel
        self.subsystem = subsystem
    }

    /// Creates a logger configured from stored user preferences.
    ///
    /// - Parameters:
    ///   - log: The in-memory record store.
    ///   - preferences: The preferences to read. They are never modified.
    public init(log: DiagnosticsLog, preferences: UserPreferences) {
        self.init(
            log: log,
            diagnosticsEnabled: preferences.diagnosticsEnabled,
            minimumLevel: preferences.loggingLevel
        )
    }

    /// Records a diagnostic event.
    ///
    /// - Parameters:
    ///   - level: The severity level.
    ///   - category: The producing subsystem.
    ///   - message: A human-readable description, free of raw audio and PII.
    ///   - date: The event timestamp. Defaults to now.
    public func record(
        _ level: LogLevel,
        category: DiagnosticsCategory,
        _ message: String,
        at date: Date = Date()
    ) {
        guard shouldRecord(level) else { return }
        let entry = DiagnosticsRecord(
            timestamp: date, level: level, category: category, message: message)
        log.record(entry)
        emitToSystemLog(entry)
    }

    /// Whether an event of the given level is recorded under the current
    /// preferences.
    ///
    /// When diagnostics are disabled only errors and critical events are kept,
    /// so failures remain traceable (`TRD` FR-DG-002).
    ///
    /// - Parameter level: The severity to test.
    public func shouldRecord(_ level: LogLevel) -> Bool {
        guard diagnosticsEnabled else { return Self.severity(level) >= Self.severity(.error) }
        return Self.severity(level) >= Self.severity(minimumLevel)
    }

    // MARK: Private

    private static func severity(_ level: LogLevel) -> Int {
        switch level {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }

    /// Emits to the unified log. Failures here are ignored by design: logging is
    /// best effort and must never affect application behavior.
    private func emitToSystemLog(_ entry: DiagnosticsRecord) {
        let logger = Logger(subsystem: subsystem, category: entry.category.rawValue)
        let message = entry.message
        switch entry.level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        case .critical: logger.critical("\(message, privacy: .public)")
        }
    }
}
