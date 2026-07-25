/// An event that can drive a runtime state transition (`ALGORITHM` §21.15).
public enum RuntimeEvent: String, Sendable, Equatable, CaseIterable {

    /// Initialization completed successfully.
    case initializationComplete

    /// A candidate tap was detected.
    case candidateDetected

    /// Processing finished without a command being executed (the candidate was
    /// rejected, unknown, or ambiguous).
    case processingFinishedWithoutExecution

    /// A command was executed following an accepted recognition.
    case commandExecuted

    /// The cooldown interval expired.
    case cooldownExpired

    /// Calibration started.
    case calibrationStarted

    /// Calibration finished.
    case calibrationFinished

    /// An unrecoverable failure occurred.
    case fatalError

    /// A recoverable failure was repaired and the engine reinitialized.
    case recovered
}

/// The deterministic runtime state machine (`ALGORITHM` §21.15–§21.17).
///
/// Transitions are explicit and total: every `(state, event)` pair either maps
/// to exactly one next state or is rejected. The machine is a pure function of
/// its inputs — it performs no work, has no side effects, and never mutates
/// anything outside itself, so identical inputs always produce the identical
/// sequence of states (§21.17).
///
/// Only the documented unrecoverable conditions reach ``RuntimeState/error``,
/// via ``RuntimeEvent/fatalError``.
public struct RuntimeStateMachine: Sendable, Equatable {

    /// The current state.
    public private(set) var state: RuntimeState

    /// Creates a state machine.
    ///
    /// - Parameter state: The initial state. Defaults to ``RuntimeState/idle``.
    public init(state: RuntimeState = .idle) {
        self.state = state
    }

    /// The state that an event leads to, without applying it.
    ///
    /// - Parameters:
    ///   - event: The event to evaluate.
    ///   - state: The state to evaluate from.
    /// - Returns: The next state, or `nil` if the event is not valid in that
    ///   state.
    public static func nextState(after event: RuntimeEvent, from state: RuntimeState)
        -> RuntimeState?
    {
        // A fatal error is accepted from any state (§21.15: "Any State").
        if event == .fatalError { return .error }

        switch (state, event) {
        case (.idle, .initializationComplete): return .listening
        case (.idle, .calibrationStarted): return .calibrating

        case (.listening, .candidateDetected): return .processing
        case (.listening, .calibrationStarted): return .calibrating

        // Processing covers candidate validation, feature extraction,
        // classification, and validation (§21.15's intermediate stages).
        case (.processing, .processingFinishedWithoutExecution): return .listening
        case (.processing, .commandExecuted): return .cooldown

        case (.cooldown, .cooldownExpired): return .listening

        case (.calibrating, .calibrationFinished): return .idle

        // Recovery from a recoverable failure returns the engine to listening
        // by way of reinitialization (§21.14).
        case (.error, .recovered): return .listening

        default: return nil
        }
    }

    /// Applies an event if it is valid in the current state.
    ///
    /// - Parameter event: The event to apply.
    /// - Returns: `true` if the event caused a transition; `false` if the event
    ///   is not valid in the current state, in which case the state is unchanged.
    @discardableResult
    public mutating func apply(_ event: RuntimeEvent) -> Bool {
        guard let next = Self.nextState(after: event, from: state) else { return false }
        state = next
        return true
    }

    /// Whether recognition may run in the current state.
    ///
    /// Recognition is suspended while calibrating and in the error state
    /// (§21.13).
    public var acceptsAudioFrames: Bool {
        state == .listening || state == .processing || state == .cooldown
    }
}
