/// Decides whether an analysis frame contains a potential tap
/// (`ALGORITHM` §22.4 / §23.4).
///
/// Detection operates on the band-pass-filtered, **pre-normalization** signal:
/// absolute energy comparisons are meaningless after peak normalization. The
/// peak search window is the analysis frame itself.
public struct CandidateDetector: Sendable, Equatable {

    /// Minimum peak magnitude for a frame to become a candidate.
    public let peakThreshold: Double

    /// Creates a detector.
    ///
    /// - Parameter peakThreshold: Minimum peak magnitude of the filtered signal.
    ///   Defaults to ``DetectionConstants/detectionPeakThreshold``.
    public init(peakThreshold: Double = DetectionConstants.detectionPeakThreshold) {
        self.peakThreshold = peakThreshold
    }

    /// Whether the filtered frame contains a candidate transient (§23.4).
    ///
    /// - Parameter filteredSignal: The band-pass-filtered, pre-normalization
    ///   frame.
    /// - Returns: `true` when the frame's peak magnitude reaches the threshold;
    ///   `false` otherwise (including for an empty frame).
    public func detectsCandidate(inFiltered filteredSignal: [Double]) -> Bool {
        guard !filteredSignal.isEmpty else { return false }
        let peak = filteredSignal.reduce(0.0) { Swift.max($0, abs($1)) }
        return peak >= peakThreshold
    }
}
