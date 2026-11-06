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
    private var pump: EventPump
    private let pollInterval: TimeInterval
    private let logger: DiagnosticsLogger?

    private var session: CalibrationSession
    private var detector: TapDetector
    private var nonDetectionSamples: [NonDetectionSample] = []
    private var events: [(EventTelemetry, FeatureVector)] = []

    /// The current calibration state, as reported by the calibration engine.
    public var state: CalibrationState { session.state }

    /// The number of samples required per zone, from the calibration
    /// configuration.
    public let samplesPerZone: Int

    /// The detector's current ambient noise-floor RMS, or `nil` before any
    /// quiet frame. Diagnostic only.
    public var noiseFloorRMS: Double? { detector.currentNoiseFloorRMS }

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
    ///   - pollInterval: How often to check the ring buffer for a new frame.
    ///   - logger: Optional diagnostics logger.
    public init(
        session: CalibrationSession,
        detector: TapDetector,
        buffer: RollingAudioBuffer,
        samplesPerZone: Int,
        pollInterval: TimeInterval = 0.020,
        logger: DiagnosticsLogger? = nil
    ) {
        self.session = session
        self.detector = detector
        self.buffer = buffer
        self.samplesPerZone = samplesPerZone
        self.pump = EventPump(frameSize: detector.frameSize, hopSize: detector.frameSize / 2)
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
        events.removeAll()
        session.begin()
        logger?.record(.info, category: .calibration, "calibration started", at: Date())
    }

    /// Waits for one tap and offers it to the calibration session.
    ///
    /// Audio captured before the call is ignored: the operator is prompted
    /// first, then the stream is examined from the present. A detected event is
    /// measured over its onset-anchored window (`ALGORITHM` §23.4.1).
    /// Detected-but-rejected taps and timeouts are reported so the operator can
    /// retry; neither advances the session.
    ///
    /// - Parameter timeout: How long to wait for a tap, in seconds.
    /// - Returns: The capture result.
    public func captureSample(timeout: TimeInterval) -> CalibrationCaptureResult {
        guard case .collecting = session.state else { return .notCollecting }

        pump.resume(at: buffer.totalSamplesWritten)
        let windowStart = nonDetectionSamples.count
        defer { lastListeningWindow = Self.summarise(nonDetectionSamples[windowStart...]) }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for outcome in pump.poll(buffer: buffer, detector: &detector, at: Date()) {
                switch outcome {
                case .noCandidate:
                    continue
                case .rejected(let reason):
                    logger?.record(
                        .info, category: .calibration, "sample rejected: \(reason)", at: Date())
                    return .rejected(reason)
                case .candidate(let candidate):
                    if let event = candidate.event {
                        events.append((event, candidate.featureVector))
                    }
                    return offer(candidate.featureVector)
                }
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return .timedOut
    }

    /// What the detector heard during the most recent ``captureSample(timeout:)``
    /// call, from frames that stayed below the detection gate. Diagnostic only:
    /// it explains a timeout without changing any decision.
    public private(set) var lastListeningWindow: ListeningWindowSummary?

    private static func summarise(_ samples: ArraySlice<NonDetectionSample>)
        -> ListeningWindowSummary
    {
        ListeningWindowSummary(
            framesExamined: samples.count,
            loudestFilteredPeak: samples.map(\.filteredPeak).max() ?? 0,
            loudestPrefilterPeak: samples.map(\.prefilterPeak).max() ?? 0)
    }

    /// Localisation and decay statistics over the events captured this
    /// session, or `nil` if none. Diagnostic only; nothing is derived from it.
    public var eventStatistics: EventStatistics? { EventStatistics.make(from: events) }

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
}

/// What the detector heard below its gate during one listening window.
public struct ListeningWindowSummary: Sendable, Equatable {

    /// Frames examined that did not reach the detection gate.
    public let framesExamined: Int

    /// The loudest band-pass-filtered peak among them; the detection gate
    /// compares this quantity against its threshold.
    public let loudestFilteredPeak: Double

    /// The loudest peak before filtering.
    public let loudestPrefilterPeak: Double
}
