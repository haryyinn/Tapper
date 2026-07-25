/// The operational state of the recognition engine (`DATA_MODELS` §3.12).
///
/// This is the **public lifecycle state**, exposed through ``EngineStatus``. The
/// finer-grained stages of `ALGORITHM` §21.15 — candidate detection, feature
/// extraction, classification, validation, command execution — are the internal
/// processing sequence performed while the state is ``processing``, and are not
/// exposed as public states. Both documents are preserved without duplicating
/// state.
public enum RuntimeState: String, Sendable, Equatable, CaseIterable {

    /// Initialized but not yet listening.
    case idle

    /// Listening for taps; audio is streaming and the buffer is updating.
    case listening

    /// Processing a candidate through detection → classification → execution.
    case processing

    /// Suppressing execution after a successful recognition.
    case cooldown

    /// Collecting calibration samples; recognition is not running.
    case calibrating

    /// An unrecoverable failure has suspended recognition.
    case error
}
