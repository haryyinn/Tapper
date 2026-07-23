/// The lifecycle state of an acoustic candidate (`DATA_MODELS` §3.11).
///
/// Candidates progress sequentially: detected → validated → classified, with
/// `rejected` terminating the lifecycle at any validation stage.
public enum CandidateStatus: Sendable, Equatable {
    case detected
    case validated
    case rejected
    case classified
}
