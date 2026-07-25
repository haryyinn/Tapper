import Configuration
import Foundation

/// The subsystem responsible for a diagnostic event (`DATA_MODELS` §11.4).
///
/// Every ``DiagnosticsRecord`` belongs to exactly one category.
public enum DiagnosticsCategory: String, Sendable, Equatable, Codable, CaseIterable {
    case audio
    case dsp
    case calibration
    case classification
    case recognition
    case runtime
    case storage
    case command
}

/// A single diagnostic event generated during execution (`DATA_MODELS` §11.3).
///
/// Immutable and purely observational: recording an event never influences
/// recognition, execution, or configuration (§11.13).
///
/// Messages are human-readable descriptions only. They shall never contain raw
/// microphone data, personally identifiable information, or secrets
/// (`IMPLEMENTATION_RULES` §Logging, `DATA_MODELS` §11.12).
public struct DiagnosticsRecord: Sendable, Equatable, Codable {

    /// Unique record identifier.
    public let id: UUID

    /// The event timestamp.
    public let timestamp: Date

    /// The severity level.
    public let level: LogLevel

    /// The subsystem that produced the event.
    public let category: DiagnosticsCategory

    /// A human-readable description of the event.
    public let message: String

    /// Creates a diagnostic record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a freshly generated `UUID`.
    ///   - timestamp: The event timestamp.
    ///   - level: The severity level.
    ///   - category: The producing subsystem.
    ///   - message: A human-readable description.
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        category: DiagnosticsCategory,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }

    /// Whether the record satisfies the validation rules of `DATA_MODELS`
    /// §11.10 (valid timestamp, level, category, and a non-empty message).
    ///
    /// Invalid diagnostic data is discarded rather than propagated (§11.10), so
    /// validity is reported rather than thrown: a malformed record must never
    /// surface an error into the observed subsystem.
    public var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && timestamp.timeIntervalSince1970.isFinite
    }
}
