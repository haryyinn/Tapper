import Foundation

/// A non-blocking cooldown gate suppressing duplicate recognitions of a single
/// physical tap (`ALGORITHM` §18.14, §23.13, §27.9).
///
/// §23.13's pseudocode waits for the cooldown to elapse; the real-time-safe,
/// deterministic realization compares timestamps instead — no blocking, no
/// timers. Timestamps are injected by the caller, keeping the gate fully
/// testable and deterministic.
///
/// The gate is consulted after classification accepts a result and before
/// command execution (§23.3); ownership of the mechanism lies with Detection.
public struct CooldownGate: Sendable, Equatable {

    /// The cooldown duration, in seconds.
    public let duration: TimeInterval

    private var lastRecognition: Date?

    /// Creates a cooldown gate.
    ///
    /// - Parameter duration: The cooldown duration in seconds. Defaults to
    ///   ``DetectionConstants/cooldownDuration`` (100 ms, `ALGORITHM` §27.9).
    public init(duration: TimeInterval = DetectionConstants.cooldownDuration) {
        self.duration = duration
    }

    /// Whether the cooldown is active at the given instant.
    ///
    /// - Parameter date: The instant to evaluate.
    /// - Returns: `true` if a recognition occurred less than ``duration`` ago.
    public func isActive(at date: Date) -> Bool {
        guard let lastRecognition else { return false }
        return date.timeIntervalSince(lastRecognition) < duration
    }

    /// Records a successful recognition, starting the cooldown interval.
    ///
    /// - Parameter date: The recognition instant.
    public mutating func recordRecognition(at date: Date) {
        lastRecognition = date
    }
}
