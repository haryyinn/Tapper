import Calibration
import Configuration
import Foundation

/// A failure encountered while exporting a diagnostics bundle.
///
/// Export is user-initiated, so failures are reported to the caller that
/// requested the export. They never propagate into recognition, execution, or
/// configuration.
public enum DiagnosticsExportError: Error, Equatable {

    /// The bundle could not be serialized.
    case encodingFailed(String)

    /// The bundle could not be written to the destination.
    case writeFailed(String)
}

/// Assembles and writes diagnostics bundles (`TRD` FR-DG-003).
///
/// Exports are **always user-initiated** and written to a caller-specified
/// destination: nothing is exported automatically and nothing is ever uploaded
/// (`DECISIONS` ADR-001, ADR-010). Bundles are JSON (UTF-8, ISO-8601 dates,
/// sorted keys) and written atomically, so a partially written bundle is never
/// left behind.
///
/// No audio is collected, referenced, or written.
public struct DiagnosticsExporter {

    private let log: DiagnosticsLog
    private let recognitionLog: RecognitionLog

    /// Creates an exporter over the observed logs.
    ///
    /// - Parameters:
    ///   - log: The diagnostic record store.
    ///   - recognitionLog: The recognition history.
    public init(log: DiagnosticsLog, recognitionLog: RecognitionLog) {
        self.log = log
        self.recognitionLog = recognitionLog
    }

    /// Assembles a bundle from the current observations and the supplied state.
    ///
    /// The configuration and calibration values are provided by the caller
    /// (Configuration owns them); the exporter only reads and copies them.
    ///
    /// - Parameters:
    ///   - calibrationProfile: The active profile, or `nil` if uncalibrated.
    ///   - preferences: The stored preferences.
    ///   - commandBindings: The stored bindings.
    ///   - performance: Runtime measurements, if available.
    ///   - appVersion: The application version string.
    ///   - osVersion: The operating system version string.
    ///   - date: The generation timestamp.
    /// - Returns: The assembled bundle.
    public func makeBundle(
        calibrationProfile: CalibrationProfile?,
        preferences: UserPreferences,
        commandBindings: PersistedCommandBindings,
        performance: PerformanceMetrics? = nil,
        appVersion: String,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        date: Date = Date()
    ) -> DiagnosticsBundle {
        DiagnosticsBundle(
            generatedAt: date,
            appVersion: appVersion,
            osVersion: osVersion,
            records: log.records,
            recognitionHistory: recognitionLog.entries,
            calibrationProfile: calibrationProfile,
            preferences: preferences,
            commandBindings: commandBindings,
            performance: performance
        )
    }

    /// Serializes a bundle as JSON.
    ///
    /// - Parameter bundle: The bundle to encode.
    /// - Returns: The encoded bytes.
    /// - Throws: ``DiagnosticsExportError/encodingFailed(_:)`` on failure.
    public func encode(_ bundle: DiagnosticsBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        do {
            return try encoder.encode(bundle)
        } catch {
            throw DiagnosticsExportError.encodingFailed(String(describing: error))
        }
    }

    /// Writes a bundle atomically to a caller-specified destination.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to export.
    ///   - destination: The file URL to write. Its directory is used for the
    ///     temporary file so the replacement is atomic.
    /// - Throws: ``DiagnosticsExportError`` if encoding or writing fails.
    public func export(_ bundle: DiagnosticsBundle, to destination: URL) throws {
        let data = try encode(bundle)
        let store = AtomicFileStore(directory: destination.deletingLastPathComponent())
        do {
            try store.write(data, to: destination.lastPathComponent)
        } catch {
            throw DiagnosticsExportError.writeFailed(String(describing: error))
        }
    }
}
