import Audio
import Calibration
import Detection
import Diagnostics
import Features
import Foundation

/// The result of attempting to capture one calibration sample.
public enum CalibrationCaptureResult: Sendable, Equatable {

    /// A tap was detected and accepted for `zone`; `acceptedInZone` collected.
    case accepted(zone: InteractionZone, acceptedInZone: Int)

    /// A tap was detected but rejected during validation. The operator retries.
    case rejected(RejectionReason)

    /// No tap was detected within the allotted time. The operator retries.
    case timedOut

    /// The session is not collecting samples.
    case notCollecting
}

/// Coordinates guided calibration (`CALIBRATION` §5.6).
///
/// Runs the documented collection sequence — prompt, capture, process, extract
/// features, validate, store, repeat — by delegating each step to its owning
/// subsystem:
///
/// - `Detection` detects and validates the tap and produces its feature vector,
/// - `Calibration` accumulates samples and computes the statistical model,
/// - `Diagnostics` observes.
///
/// The coordinator owns **sequencing only**. It contains no calibration
/// mathematics, no sample-validation rules, and no detection thresholds. It
/// never persists: the caller hands the generated profile to Configuration.
///
/// - Note: ``captureSample(timeout:)`` blocks the calling thread while it waits
///   for a tap, so it is intended for a dedicated calibration flow rather than a
///   user-interface thread.
public final class CalibrationCoordinator {

    private let buffer: RollingAudioBuffer
    private let extractor: AnalysisFrameExtractor
    private let pollInterval: TimeInterval
    private let logger: DiagnosticsLogger?

    private var session: CalibrationSession
    private var detector: TapDetector
    private var nonDetectionSamples: [NonDetectionSample] = []

    /// The current calibration state, as reported by the calibration engine.
    public var state: CalibrationState { session.state }

    /// The number of samples required per zone, from the calibration
    /// configuration.
    public let samplesPerZone: Int

    /// Aggregate statistics over frames that never became candidates, or `nil`
    /// if none were observed. Diagnostic only.
    public var nonDetectionStatistics: NonDetectionStatistics? {
        NonDetectionStatistics.make(from: nonDetectionSamples)
    }

    /// Creates a calibration coordinator.
    ///
    /// - Parameters:
    ///   - session: The calibration engine, which owns the statistics.
    ///   - detector: The tap detector, which owns detection and validation.
    ///   - buffer: The ring buffer written by the audio callback.
    ///   - samplesPerZone: Samples required per zone, matching the session's
    ///     configuration.
    ///   - extractor: The analysis-frame configuration.
    ///   - pollInterval: How often to check the ring buffer for a new frame.
    ///   - logger: Optional diagnostics logger.
    public init(
        session: CalibrationSession,
        detector: TapDetector,
        buffer: RollingAudioBuffer,
        samplesPerZone: Int,
        extractor: AnalysisFrameExtractor = .v1,
        pollInterval: TimeInterval = 0.020,
        logger: DiagnosticsLogger? = nil
    ) {
        self.session = session
        self.detector = detector
        self.buffer = buffer
        self.samplesPerZone = samplesPerZone
        self.extractor = extractor
        self.pollInterval = pollInterval
        self.logger = logger
        // Instrumentation only: records why frames failed detection without
        // altering the decision.
        self.detector.nonDetectionObserver = { [weak self] sample in
            self?.nonDetectionSamples.append(sample)
        }
    }

    /// Starts collection at the first canonical zone.
    public func begin() {
        nonDetectionSamples.removeAll()
        session.begin()
        logger?.record(.info, category: .calibration, "calibration started", at: Date())
    }

    /// Waits for one tap and offers it to the calibration session.
    ///
    /// Frames are read from the ring buffer and passed to the detector until a
    /// candidate is produced or `timeout` elapses. Detected-but-rejected taps
    /// and timeouts are reported so the operator can retry; neither advances
    /// the session.
    ///
    /// - Parameter timeout: How long to wait for a tap, in seconds.
    /// - Returns: The capture result.
    public func captureSample(timeout: TimeInterval) -> CalibrationCaptureResult {
        guard case .collecting = session.state else { return .notCollecting }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let frame = nextFrame() else {
                Thread.sleep(forTimeInterval: pollInterval)
                continue
            }
            switch detector.process(frame: frame, at: Date()) {
            case .noCandidate:
                continue
            case .rejected(let reason):
                logger?.record(
                    .info, category: .calibration, "sample rejected: \(reason)", at: Date())
                return .rejected(reason)
            case .candidate(let candidate):
                return offer(candidate.featureVector)
            }
        }
        return .timedOut
    }

    /// Offers a feature vector directly, bypassing capture.
    ///
    /// Used by tests and tooling that supply vectors explicitly.
    ///
    /// - Parameter vector: The candidate feature vector.
    /// - Returns: The capture result.
    @discardableResult
    public func offer(_ vector: FeatureVector) -> CalibrationCaptureResult {
        switch session.addSample(vector) {
        case .accepted(let zone, let acceptedInZone):
            logger?.record(
                .info, category: .calibration,
                "sample accepted for \(zone.rawValue): \(acceptedInZone)/\(samplesPerZone)",
                at: Date())
            return .accepted(zone: zone, acceptedInZone: acceptedInZone)
        case .rejectedInvalidFeatureVector:
            logger?.record(
                .info, category: .calibration, "sample rejected: invalid feature vector",
                at: Date())
            return .rejected(.invalidFeatureVector)
        case .notCollecting:
            return .notCollecting
        }
    }

    /// Generates the calibration profile once every zone is complete.
    ///
    /// The mathematics belong to `Calibration`; this only forwards the request
    /// and observes the outcome. Persisting the profile is the caller's
    /// responsibility, through Configuration.
    ///
    /// - Parameter createdAt: The creation timestamp recorded in the profile.
    /// - Returns: The generated profile, or the calibration failure.
    public func generateProfile(createdAt: Date = Date())
        -> Result<CalibrationProfile, CalibrationError>
    {
        let result = session.generateProfile(createdAt: createdAt)
        switch result {
        case .success:
            logger?.record(.info, category: .calibration, "profile generated", at: Date())
        case .failure(let error):
            logger?.record(
                .error, category: .calibration, "profile generation failed: \(error)", at: Date())
        }
        return result
    }

    /// Reads one complete analysis frame from the ring buffer, if available.
    private func nextFrame() -> [Double]? {
        guard buffer.availableSampleCount >= extractor.frameSize else { return nil }
        let samples = buffer.latestSamples(extractor.frameSize)
        guard samples.count == extractor.frameSize else { return nil }
        return samples.map(Double.init)
    }
}
