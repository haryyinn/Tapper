import DSP
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

    /// How the event was localised and measured, for telemetry. `nil` for
    /// candidates not produced by event extraction.
    public let event: EventTelemetry?

    /// Creates a candidate.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a freshly generated `UUID`.
    ///   - featureVector: The extracted acoustic features.
    ///   - detectedAt: The detection timestamp.
    ///   - status: The current processing state.
    ///   - event: Localisation and measurement telemetry.
    public init(
        id: UUID = UUID(),
        featureVector: FeatureVector,
        detectedAt: Date,
        status: CandidateStatus,
        event: EventTelemetry? = nil
    ) {
        self.id = id
        self.featureVector = featureVector
        self.detectedAt = detectedAt
        self.status = status
        self.event = event
    }

    /// Returns a copy of the candidate in a new lifecycle state, preserving its
    /// identity and features.
    ///
    /// - Parameter status: The new processing state.
    public func withStatus(_ status: CandidateStatus) -> Candidate {
        Candidate(
            id: id, featureVector: featureVector, detectedAt: detectedAt, status: status,
            event: event)
    }
}

/// How one event was localised and measured (`ALGORITHM` §23.4.1, §14.13.4).
///
/// Instrumentation only: nothing downstream decides on it.
public struct EventTelemetry: Sendable, Equatable {

    /// Onset position relative to the peak of the frame that detected the
    /// event, in samples. Negative when the onset preceded that peak.
    public let onsetOffsetSamples: Int

    /// The event window length actually measured, in samples.
    public let windowSamples: Int

    /// The decay estimate with its reliability metadata.
    public let decay: DecayEstimate

    /// Creates event telemetry.
    public init(onsetOffsetSamples: Int, windowSamples: Int, decay: DecayEstimate) {
        self.onsetOffsetSamples = onsetOffsetSamples
        self.windowSamples = windowSamples
        self.decay = decay
    }
}
