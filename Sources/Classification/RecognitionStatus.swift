/// The outcome of a recognition attempt (`DATA_MODELS` §3.10).
///
/// The classifier produces `success`, `ambiguous`, or `unknown`. `cooldown` is
/// applied by the runtime cooldown gate, and `error`/`rejected` by other
/// pipeline stages; the full set is defined here for the canonical model.
public enum RecognitionStatus: Sendable, Equatable {
    case success
    case rejected
    case ambiguous
    case unknown
    case cooldown
    case error
}
