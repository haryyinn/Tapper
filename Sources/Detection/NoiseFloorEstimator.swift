/// A deterministic estimate of the ambient noise floor (`ALGORITHM` §19.17).
///
/// The specification requires continuous noise-floor monitoring for candidate
/// validation but does not define the estimation method; the approved
/// implementation is an exponential moving average of frame RMS over
/// **non-candidate frames only**. The estimate supports validation exclusively —
/// it never modifies calibrated statistical models.
///
/// The first observation seeds the estimate directly, so a usable value exists
/// after one non-candidate frame.
public struct NoiseFloorEstimator: Sendable, Equatable {

    /// The EMA smoothing factor applied to new observations.
    public let smoothing: Double

    /// The current noise-floor RMS estimate, or `nil` before any observation.
    public private(set) var currentRMS: Double?

    /// Creates an estimator.
    ///
    /// - Parameter smoothing: The EMA smoothing factor. Defaults to
    ///   ``DetectionConstants/noiseFloorSmoothing``.
    public init(smoothing: Double = DetectionConstants.noiseFloorSmoothing) {
        self.smoothing = smoothing
        self.currentRMS = nil
    }

    /// Updates the estimate with the RMS of a non-candidate frame.
    ///
    /// Negative or non-finite observations are ignored.
    ///
    /// - Parameter rms: The frame's RMS energy.
    public mutating func update(withFrameRMS rms: Double) {
        guard rms.isFinite, rms >= 0 else { return }
        if let current = currentRMS {
            currentRMS = smoothing * rms + (1 - smoothing) * current
        } else {
            currentRMS = rms
        }
    }
}
