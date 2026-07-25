import Calibration
import Classification
import Configuration
import Foundation

/// A user-initiated export of diagnostic information (`TRD` FR-DG-003).
///
/// The bundle contains logs, the calibration profile, the current configuration,
/// and OS/app version information. It deliberately contains **no audio of any
/// kind** — no raw microphone recordings, buffered samples, or derived audio
/// files — because serialized diagnostics shall exclude raw microphone
/// recordings (`DATA_MODELS` §11.12) and audio shall not be persisted
/// (`IMPLEMENTATION_RULES` §Audio Rules), which take precedence over the TRD's
/// "optional captured audio".
///
/// Everything stays on the device: the bundle is written to a caller-specified
/// destination and is never uploaded (`DECISIONS` ADR-001, ADR-010).
public struct DiagnosticsBundle: Sendable, Equatable, Codable {

    /// The schema version of the exported bundle.
    public let schemaVersion: String

    /// When the bundle was generated.
    public let generatedAt: Date

    /// The application version.
    public let appVersion: String

    /// The operating system version.
    public let osVersion: String

    /// The recorded diagnostic events.
    public let records: [DiagnosticsRecord]

    /// The recognition history, if included.
    public let recognitionHistory: [ClassificationOutcome]

    /// The active calibration profile, if one is stored.
    public let calibrationProfile: CalibrationProfile?

    /// The stored user preferences.
    public let preferences: UserPreferences

    /// The stored command bindings.
    public let commandBindings: PersistedCommandBindings

    /// Runtime performance measurements, if provided by the runtime layer.
    public let performance: PerformanceMetrics?

    /// Creates a diagnostics bundle.
    public init(
        schemaVersion: String = SchemaVersion.current,
        generatedAt: Date,
        appVersion: String,
        osVersion: String,
        records: [DiagnosticsRecord],
        recognitionHistory: [ClassificationOutcome],
        calibrationProfile: CalibrationProfile?,
        preferences: UserPreferences,
        commandBindings: PersistedCommandBindings,
        performance: PerformanceMetrics?
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.records = records
        self.recognitionHistory = recognitionHistory
        self.calibrationProfile = calibrationProfile
        self.preferences = preferences
        self.commandBindings = commandBindings
        self.performance = performance
    }
}
