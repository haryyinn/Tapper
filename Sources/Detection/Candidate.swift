import Features
import Foundation

/// An acoustic event that has passed initial detection (`DATA_MODELS` §9.3).
///
/// A candidate is not yet a recognized tap; it indicates that the signal may
/// correspond to an intentional tap and is progressing through validation and
/// classification. Immutable — lifecycle transitions produce a new value via
/// ``withStatus(_:)``.
public struct Candidate: Sendable, Equatable {

    /// Unique candidate identifier.
    public let id: UUID

    /// The extracted acoustic features.
    public let featureVector: FeatureVector

    /// The detection timestamp.
    public let detectedAt: Date

    /// The current processing state.
    public let status: CandidateStatus

    /// Creates a candidate.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a freshly generated `UUID`.
    ///   - featureVector: The extracted acoustic features.
    ///   - detectedAt: The detection timestamp.
    ///   - status: The current processing state.
    public init(
        id: UUID = UUID(),
        featureVector: FeatureVector,
        detectedAt: Date,
        status: CandidateStatus
    ) {
        self.id = id
        self.featureVector = featureVector
        self.detectedAt = detectedAt
        self.status = status
    }

    /// Returns a copy of the candidate in a new lifecycle state, preserving its
    /// identity and features.
    ///
    /// - Parameter status: The new processing state.
    public func withStatus(_ status: CandidateStatus) -> Candidate {
        Candidate(id: id, featureVector: featureVector, detectedAt: detectedAt, status: status)
    }
}
