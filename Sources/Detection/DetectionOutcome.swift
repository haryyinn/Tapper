/// The result of processing one analysis frame through tap detection.
public enum DetectionOutcome: Sendable, Equatable {

    /// The frame contained no candidate transient (`ALGORITHM` §23.4); it
    /// contributes to the ambient noise-floor estimate.
    case noCandidate

    /// A candidate was detected but rejected during validation, with the first
    /// failing check's reason (`ALGORITHM` §23.5, §19.18).
    case rejected(RejectionReason)

    /// A validated candidate carrying its extracted feature vector, ready for
    /// classification (Phase 4).
    case candidate(Candidate)
}
