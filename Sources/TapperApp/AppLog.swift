import Foundation
import os

/// Stage tracing for the application workflows.
///
/// Writes to the unified log so the exact stopping point of a workflow is
/// visible when the app runs from a bundle (where stdout is not attached to a
/// terminal). View the trace with:
///
///     log stream --predicate 'subsystem == "com.tapper.Tapper"' --info
///
/// This records progress only; it never influences behaviour.
enum AppLog {

    private static let calibrationLogger = Logger(
        subsystem: "com.tapper.Tapper", category: "calibration")
    private static let validationLogger = Logger(
        subsystem: "com.tapper.Tapper", category: "validation")
    private static let engineLogger = Logger(subsystem: "com.tapper.Tapper", category: "engine")

    /// Traces a calibration stage.
    static func calibration(_ message: String) {
        calibrationLogger.info("[Calibration] \(message, privacy: .public)")
    }

    /// Traces a validation stage.
    static func validation(_ message: String) {
        validationLogger.info("[Validation] \(message, privacy: .public)")
    }

    /// Traces an engine stage.
    static func engine(_ message: String) {
        engineLogger.info("[Engine] \(message, privacy: .public)")
    }
}
