import Foundation

/// Decides how long one validation trial listens for the operator's tap.
///
/// A **timeout that closes early**, not a fixed window. The trial ends shortly
/// after audio is heard, so the timeout can be generous without lengthening
/// trials where the operator taps promptly.
///
/// The previous fixed 1.2 s window was shorter than the operator's reaction
/// time (median 771 ms, maximum 1168 ms — itself censored by the very window
/// that measured it), so taps landed after the window closed and were recorded
/// as recognition failures. Sizing a limit from a measurement that the limit
/// truncates is the error ADR-017 corrects in the signal path; this is the same
/// error in the measuring instrument.
///
/// Clock and sleep are injected so the policy is testable without real time.
struct TapWindowPolicy: Sendable {

    /// How the window closed.
    enum Closure: Equatable {
        /// Audio was heard; the window stayed open for the settle period.
        case heard
        /// Nothing was heard before the timeout. The trial is a genuine miss.
        case timedOut
        /// The run was cancelled.
        case cancelled
    }

    /// Longest time to wait for audio, in seconds.
    let timeout: TimeInterval

    /// How long to keep listening after audio is first heard, so the frames
    /// that classify the tap are still observed.
    let settle: TimeInterval

    /// How often to check for audio, in seconds.
    let poll: TimeInterval

    /// Creates a policy.
    init(timeout: TimeInterval, settle: TimeInterval, poll: TimeInterval = 0.02) {
        self.timeout = Swift.max(0.1, timeout)
        self.settle = Swift.max(0, settle)
        self.poll = Swift.max(0.001, poll)
    }

    /// Waits for the operator's tap.
    ///
    /// - Parameters:
    ///   - now: The current time.
    ///   - heardAudio: Whether audio has been observed in this trial.
    ///   - isCancelled: Whether the run has been cancelled.
    ///   - sleep: Suspends for the given interval.
    /// - Returns: How the window closed.
    func wait(
        now: () -> Date,
        heardAudio: () -> Bool,
        isCancelled: () -> Bool,
        sleep: (TimeInterval) -> Void
    ) -> Closure {
        let deadline = now().addingTimeInterval(timeout)
        while now() < deadline {
            if isCancelled() { return .cancelled }
            if heardAudio() {
                // Keep listening: the frames that classify the tap arrive after
                // the first frame that merely noticed it.
                sleep(settle)
                return .heard
            }
            sleep(poll)
        }
        // A final check: audio may have arrived during the last poll interval.
        return heardAudio() ? .heard : .timedOut
    }
}
