import Calibration
import Configuration
import Foundation

/// Operational settings used by the recognition engine (`DATA_MODELS` §10.3).
///
/// Contains only configurable runtime behavior; it never influences the
/// statistical model, and changing it never invalidates a calibration profile.
public struct RuntimeConfiguration: Sendable, Equatable {

    /// Whether runtime diagnostics are enabled.
    public let diagnosticsEnabled: Bool

    /// The duplicate-suppression period, in seconds.
    public let cooldownDuration: TimeInterval

    /// Whether recognition is enabled.
    public let recognitionEnabled: Bool

    /// The diagnostic logging level.
    public let loggingLevel: LogLevel

    /// Creates a runtime configuration.
    public init(
        diagnosticsEnabled: Bool,
        cooldownDuration: TimeInterval,
        recognitionEnabled: Bool,
        loggingLevel: LogLevel
    ) {
        self.diagnosticsEnabled = diagnosticsEnabled
        self.cooldownDuration = cooldownDuration
        self.recognitionEnabled = recognitionEnabled
        self.loggingLevel = loggingLevel
    }

    /// Derives a runtime configuration from stored preferences.
    ///
    /// Preferences are owned by Configuration and are only read here.
    ///
    /// - Parameters:
    ///   - preferences: The stored user preferences.
    ///   - cooldownDuration: The cooldown period, owned by Detection.
    ///   - recognitionEnabled: Whether recognition should run.
    public init(
        preferences: UserPreferences,
        cooldownDuration: TimeInterval,
        recognitionEnabled: Bool = true
    ) {
        self.init(
            diagnosticsEnabled: preferences.diagnosticsEnabled,
            cooldownDuration: cooldownDuration,
            recognitionEnabled: recognitionEnabled,
            loggingLevel: preferences.loggingLevel
        )
    }

    /// Whether the configuration satisfies `DATA_MODELS` §10.9 (a positive,
    /// finite cooldown duration).
    public var isValid: Bool {
        cooldownDuration.isFinite && cooldownDuration > 0
    }
}

/// The current health of the recognition engine (`DATA_MODELS` §10.4).
///
/// Immutable; reports readiness without making decisions.
public struct EngineStatus: Sendable, Equatable {

    /// The current public lifecycle state.
    public let state: RuntimeState

    /// Whether a microphone is available and permitted.
    public let microphoneAvailable: Bool

    /// Whether a valid calibration profile is loaded.
    public let profileLoaded: Bool

    /// Creates an engine status.
    ///
    /// - Parameters:
    ///   - state: The current lifecycle state.
    ///   - microphoneAvailable: Microphone availability.
    ///   - profileLoaded: Whether a calibration profile is loaded.
    public init(state: RuntimeState, microphoneAvailable: Bool, profileLoaded: Bool) {
        self.state = state
        self.microphoneAvailable = microphoneAvailable
        self.profileLoaded = profileLoaded
    }

    /// Overall engine health: the engine is healthy when it is not in the error
    /// state and both prerequisites for recognition are satisfied.
    public var healthy: Bool {
        state != .error && microphoneAvailable && profileLoaded
    }
}

/// The active runtime environment (`DATA_MODELS` §10.5).
///
/// Aggregates the objects the engine needs during execution and remains
/// immutable for the duration of a recognition cycle.
public struct RuntimeContext: Sendable, Equatable {

    /// The runtime settings in force.
    public let configuration: RuntimeConfiguration

    /// The active calibration profile.
    public let calibrationProfile: CalibrationProfile

    /// The engine status at the time the context was formed.
    public let engineStatus: EngineStatus

    /// Creates a runtime context.
    public init(
        configuration: RuntimeConfiguration,
        calibrationProfile: CalibrationProfile,
        engineStatus: EngineStatus
    ) {
        self.configuration = configuration
        self.calibrationProfile = calibrationProfile
        self.engineStatus = engineStatus
    }
}

/// Operational metrics describing engine performance (`DATA_MODELS` §10.6).
///
/// Diagnostic only: these values never participate in classification.
public struct RuntimeStatistics: Sendable, Equatable {

    /// The number of recognitions processed.
    public let recognitionsProcessed: Int

    /// The number of candidates rejected.
    public let rejectedCandidates: Int

    /// The mean end-to-end latency, in seconds.
    public let averageLatency: TimeInterval

    /// How long the engine has been running, in seconds.
    public let uptime: TimeInterval

    /// Creates runtime statistics.
    public init(
        recognitionsProcessed: Int,
        rejectedCandidates: Int,
        averageLatency: TimeInterval,
        uptime: TimeInterval
    ) {
        self.recognitionsProcessed = recognitionsProcessed
        self.rejectedCandidates = rejectedCandidates
        self.averageLatency = averageLatency
        self.uptime = uptime
    }

    /// Statistics for an engine that has not yet processed anything.
    public static let zero = RuntimeStatistics(
        recognitionsProcessed: 0, rejectedCandidates: 0, averageLatency: 0, uptime: 0)

    /// Whether the statistics satisfy `DATA_MODELS` §10.9 (non-negative counts
    /// and durations, all finite).
    public var isValid: Bool {
        averageLatency.isFinite && uptime.isFinite && recognitionsProcessed >= 0
            && rejectedCandidates >= 0 && averageLatency >= 0 && uptime >= 0
    }
}
