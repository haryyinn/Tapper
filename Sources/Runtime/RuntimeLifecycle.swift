import Calibration
import Configuration
import Foundation
import SystemIntegration

/// Why the engine cannot start listening.
///
/// Each case corresponds to a documented condition; none is inferred.
public enum StartupBlocker: Sendable, Equatable {

    /// Microphone access is unavailable, so no audio can be captured
    /// (`TRD` NFR-009 — degrade gracefully).
    case microphoneUnavailable

    /// No calibration profile is stored; the user must calibrate
    /// (`ALGORITHM` §16.19).
    case calibrationRequired

    /// A stored calibration profile could not be loaded and must be
    /// regenerated (`ALGORITHM` §21.14, non-recoverable).
    case calibrationInvalid(ConfigurationError)

    /// Recognition is disabled by configuration.
    case recognitionDisabled
}

/// The outcome of evaluating whether the engine may begin recognition.
public enum StartupOutcome: Sendable, Equatable {

    /// The engine may listen, using the loaded profile.
    case ready(CalibrationProfile)

    /// The engine cannot listen; the reason is reported so the application can
    /// degrade gracefully and inform the user.
    case blocked(StartupBlocker)
}

/// Evaluates the documented startup sequence (`ARCHITECTURE` §10).
///
/// Order: load configuration → verify permissions → load calibration → begin
/// recognition. This type performs only the evaluation; it starts no audio,
/// mutates no configuration, and makes no product decisions. Loading and
/// validation remain owned by Configuration, permission reporting by
/// SystemIntegration.
public enum RuntimeStartup {

    /// Determines whether recognition may begin.
    ///
    /// A missing or unusable calibration profile is **not** a crash: the engine
    /// reports the blocker and the application keeps running (`TRD` §8,
    /// NFR-009).
    ///
    /// - Parameters:
    ///   - capabilities: The current permission snapshot.
    ///   - recognitionEnabled: Whether configuration enables recognition.
    ///   - loadProfile: Loads the stored calibration profile, throwing if it is
    ///     stored but unusable.
    /// - Returns: The startup outcome.
    public static func evaluate(
        capabilities: SystemCapabilities,
        recognitionEnabled: Bool,
        loadProfile: () throws -> CalibrationProfile?
    ) -> StartupOutcome {
        guard recognitionEnabled else { return .blocked(.recognitionDisabled) }
        guard capabilities.allowsRecognition else { return .blocked(.microphoneUnavailable) }
        do {
            guard let profile = try loadProfile() else { return .blocked(.calibrationRequired) }
            return .ready(profile)
        } catch let error as ConfigurationError {
            return .blocked(.calibrationInvalid(error))
        } catch {
            return .blocked(
                .calibrationInvalid(.corruptedData(String(describing: error))))
        }
    }

    /// The engine status implied by a startup outcome.
    ///
    /// - Parameters:
    ///   - outcome: The startup outcome.
    ///   - capabilities: The permission snapshot used to evaluate it.
    /// - Returns: The status to publish.
    public static func status(
        for outcome: StartupOutcome, capabilities: SystemCapabilities
    ) -> EngineStatus {
        switch outcome {
        case .ready:
            return EngineStatus(
                state: .listening,
                microphoneAvailable: capabilities.allowsRecognition,
                profileLoaded: true)
        case .blocked(let blocker):
            // Only a profile that exists but cannot be used is an unrecoverable
            // error state (§21.13). Missing calibration, denied microphone, and
            // disabled recognition are ordinary non-listening conditions.
            let state: RuntimeState = {
                if case .calibrationInvalid = blocker { return .error }
                return .idle
            }()
            return EngineStatus(
                state: state,
                microphoneAvailable: capabilities.allowsRecognition,
                profileLoaded: false)
        }
    }
}
