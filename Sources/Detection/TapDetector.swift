import DSP
import Features
import Foundation

/// Orchestrates tap detection for one analysis frame
/// (`ALGORITHM` §23.2–§23.5, §21.6–21.8).
///
/// For each frame: preprocess (DC removal, band-pass filter) → candidate
/// detection on the filtered signal → validation with rejection reasons →
/// feature extraction → feature-vector integrity check → a validated
/// ``Candidate``. Non-candidate frames update the ambient noise-floor estimate;
/// frames that triggered detection never do, keeping the estimate a clean
/// measure of background noise.
///
/// Classification and the cooldown/execution decision are Phase 4/5 concerns
/// consuming the produced ``DetectionOutcome``.
///
/// - Note: feature extraction reuses ``Features/FeatureExtractionPipeline``
///   unchanged, which re-runs DC removal and filtering internally. The
///   redundant computation is accepted for simplicity and correctness; fusing
///   the stages is a profiling-driven optimization for a later phase.
public struct TapDetector {

    /// The expected frame length, in samples.
    public let frameSize: Int

    /// The sample rate, in hertz.
    public let sampleRate: Double

    private let filter: ButterworthBandpass
    private let detector: CandidateDetector
    private let validator: CandidateValidator
    private let pipeline: FeatureExtractionPipeline
    private var noiseFloor: NoiseFloorEstimator

    /// The current ambient noise-floor RMS estimate, or `nil` before any
    /// non-candidate frame has been observed. Exposed for diagnostics.
    public var currentNoiseFloorRMS: Double? { noiseFloor.currentRMS }

    /// Creates a tap detector.
    ///
    /// - Parameters:
    ///   - frameSize: The analysis frame length, in samples.
    ///   - fftSize: The FFT size for feature extraction.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - filter: The band-pass filter shared by detection and features.
    ///   - detector: The candidate detector.
    ///   - validator: The candidate validator.
    ///   - noiseFloor: The noise-floor estimator.
    /// - Throws: An error if the feature-extraction FFT cannot be created.
    public init(
        frameSize: Int,
        fftSize: Int,
        sampleRate: Double,
        filter: ButterworthBandpass,
        detector: CandidateDetector = CandidateDetector(),
        validator: CandidateValidator = CandidateValidator(),
        noiseFloor: NoiseFloorEstimator = NoiseFloorEstimator()
    ) throws {
        self.frameSize = frameSize
        self.sampleRate = sampleRate
        self.filter = filter
        self.detector = detector
        self.validator = validator
        self.pipeline = try FeatureExtractionPipeline(
            frameSize: frameSize,
            fftSize: fftSize,
            sampleRate: sampleRate,
            filter: filter
        )
        self.noiseFloor = noiseFloor
    }

    /// The Version 1 detector: 1920-sample frames, 2048-point FFT, 48 kHz,
    /// the Version 1 band-pass filter, and the approved detection defaults.
    ///
    /// - Throws: An error if the feature-extraction FFT cannot be created.
    public static func v1() throws -> TapDetector {
        try TapDetector(frameSize: 1920, fftSize: 2048, sampleRate: 48_000, filter: .v1)
    }

    /// Processes one analysis frame.
    ///
    /// - Parameters:
    ///   - frame: The frame's samples. Its count must equal ``frameSize``.
    ///   - timestamp: The frame's capture timestamp, recorded on any candidate.
    /// - Returns: The detection outcome for this frame.
    public mutating func process(frame: [Double], at timestamp: Date) -> DetectionOutcome {
        precondition(frame.count == frameSize, "frame length must equal frameSize")

        let dcRemoved = SignalPreprocessing.removeDCOffset(frame)
        let filtered = filter.process(dcRemoved)

        guard detector.detectsCandidate(inFiltered: filtered) else {
            noiseFloor.update(withFrameRMS: TimeDomainFeatures.rmsEnergy(of: filtered))
            return .noCandidate
        }

        let (normalized, _) = SignalPreprocessing.peakNormalized(filtered)
        if let reason = validator.rejectionReason(
            dcRemovedSignal: dcRemoved,
            filteredSignal: filtered,
            normalizedSignal: normalized,
            sampleRate: sampleRate,
            noiseFloorRMS: noiseFloor.currentRMS
        ) {
            return .rejected(reason)
        }

        // Defensive: the validator has already rejected clipped frames, so a
        // nil vector here is unexpected; treat it as the clipping rejection it
        // represents (§10.4).
        guard let vector = pipeline.extract(from: frame) else {
            return .rejected(.clipped)
        }
        guard vector.isValid else {
            return .rejected(.invalidFeatureVector)
        }
        return .candidate(
            Candidate(featureVector: vector, detectedAt: timestamp, status: .validated))
    }
}
