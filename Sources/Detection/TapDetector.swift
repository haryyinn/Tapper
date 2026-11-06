import DSP
import Features
import Foundation

/// A request to read one event from the sample stream (`ALGORITHM` §23.4.1).
///
/// Produced when a frame detects an event. The caller reads `readCount` raw
/// samples starting at absolute stream position `readStart`, once they have all
/// been captured, and hands them to ``TapDetector/measure(_:samples:at:)``.
public struct EventRequest: Sendable, Equatable {

    /// Absolute stream position of the first sample to read.
    public let readStart: Int

    /// Number of samples to read.
    public let readCount: Int

    /// Position of the detecting frame's peak, relative to `readStart`.
    let detectedPeakOffset: Int

    /// Earliest permitted event-window start, relative to `readStart`, so the
    /// filter warm-up precedes the window.
    let minimumWindowStart: Int

    /// Absolute stream position one past the last sample to read.
    public var readEnd: Int { readStart + readCount }
}

/// The result of offering one poll-aligned frame for detection.
public enum DetectionStep: Sendable, Equatable {

    /// The frame contains no candidate; it updated the noise floor.
    case noCandidate

    /// The frame's peak lies inside an event already extracted.
    case continuation

    /// An event was detected and must now be extracted.
    case event(EventRequest)
}

/// Orchestrates tap detection (`ALGORITHM` §23.2–§23.5, ADR-017).
///
/// Detection is split into the stages of ADR-017 §1:
///
/// 1. **Detection** (``detect(frame:startingAt:)``): a decision on the
///    poll-aligned frame using only its filtered peak magnitude. Non-candidate
///    frames update the ambient noise-floor estimate.
/// 2. **Localisation and extraction** (``measure(_:samples:at:)``): the event
///    peak and onset are found in the continuous stream and an onset-anchored
///    event window is cut from it.
/// 3. **Measurement and validation**: features, decay estimate and quality
///    gates, all over the event window.
///
/// The caller supplies samples by absolute stream position; this type holds no
/// audio between calls. ``process(frame:at:)`` runs all stages on a single
/// self-contained frame, for tooling and tests.
public struct TapDetector {

    /// The detection frame length, in samples.
    public let frameSize: Int

    /// The event-window length, in samples (`ALGORITHM` §23.4.1).
    public let eventWindowSize: Int

    /// The sample rate, in hertz.
    public let sampleRate: Double

    private let filter: ButterworthBandpass
    private let detector: CandidateDetector
    private let validator: CandidateValidator
    private let pipeline: FeatureExtractionPipeline
    private var noiseFloor: NoiseFloorEstimator

    /// Absolute stream position one past the last extracted event window.
    /// Detections peaking before it belong to that event.
    private var extractedUntil = 0

    /// Filtered peak magnitude of the last extracted event, for telling its
    /// ring from a new tap during the refractory interval.
    private var lastEventPeak = 0.0

    /// Optional observer for frames that do not become candidates.
    ///
    /// Instrumentation only. When `nil` — the default — no extra work is done
    /// and the detection path is exactly as before.
    public var nonDetectionObserver: ((NonDetectionSample) -> Void)?

    /// The current ambient noise-floor RMS estimate, or `nil` before any
    /// non-candidate frame has been observed. Exposed for diagnostics.
    public var currentNoiseFloorRMS: Double? { noiseFloor.currentRMS }

    /// Creates a tap detector.
    ///
    /// - Parameters:
    ///   - frameSize: The detection frame length, in samples.
    ///   - eventWindowSize: The event-window length, in samples. Defaults to
    ///     `frameSize`.
    ///   - fftSize: The FFT size for feature extraction (≥ the event window).
    ///   - sampleRate: The sample rate, in hertz.
    ///   - filter: The band-pass filter shared by detection and features.
    ///   - detector: The candidate detector.
    ///   - validator: The candidate validator.
    ///   - noiseFloor: The noise-floor estimator.
    /// - Throws: An error if the feature-extraction FFT cannot be created.
    public init(
        frameSize: Int,
        eventWindowSize: Int? = nil,
        fftSize: Int,
        sampleRate: Double,
        filter: ButterworthBandpass,
        detector: CandidateDetector = CandidateDetector(),
        validator: CandidateValidator = CandidateValidator(),
        noiseFloor: NoiseFloorEstimator = NoiseFloorEstimator()
    ) throws {
        self.frameSize = frameSize
        self.eventWindowSize = eventWindowSize ?? frameSize
        self.sampleRate = sampleRate
        self.filter = filter
        self.detector = detector
        self.validator = validator
        self.pipeline = try FeatureExtractionPipeline(
            frameSize: self.eventWindowSize,
            fftSize: fftSize,
            sampleRate: sampleRate,
            filter: filter
        )
        self.noiseFloor = noiseFloor
    }

    /// The Version 1 detector: 1920-sample detection frames, a 3360-sample
    /// event window with a 4096-point FFT, 48 kHz, the Version 1 band-pass
    /// filter, and the given validator.
    ///
    /// - Parameter validator: The quality gates. Calibration passes one with
    ///   no upper duration limit; runtime passes the profile's derived limit.
    /// - Throws: An error if the feature-extraction FFT cannot be created.
    public static func v1(validator: CandidateValidator = CandidateValidator()) throws
        -> TapDetector
    {
        try TapDetector(
            frameSize: DetectionConstants.detectionFrameSamples,
            eventWindowSize: DetectionConstants.eventWindowSamples,
            fftSize: DetectionConstants.eventFFTSize,
            sampleRate: 48_000, filter: .v1, validator: validator)
    }

    // MARK: Stage 1 — detection

    /// Decides whether a poll-aligned frame contains an event (§23.4).
    ///
    /// - Parameters:
    ///   - frame: The frame's raw samples. Its count must equal ``frameSize``.
    ///   - frameStart: The absolute stream position of the frame's first
    ///     sample.
    /// - Returns: The detection step.
    public mutating func detect(frame: [Double], startingAt frameStart: Int) -> DetectionStep {
        guard let (peakIndex, magnitude) = detectedPeak(in: frame) else { return .noCandidate }
        let peak = frameStart + peakIndex
        guard peak >= extractedUntil else { return .continuation }
        // A long ring can outlast the event window and re-cross the detection
        // threshold; it is quieter than the event that produced it.
        if peak < extractedUntil + DetectionConstants.refractorySamples,
            magnitude <= lastEventPeak
        {
            return .continuation
        }

        let margin = DetectionConstants.eventPreRollSamples
        let idealStart =
            peak - DetectionConstants.maximumOnsetLookBackSamples - margin
            - DetectionConstants.eventPreRollSamples - DetectionConstants.filterWarmUpSamples
        let readStart = Swift.max(0, idealStart)
        let readEnd = peak + DetectionConstants.maximumAttackSamples + eventWindowSize
        return .event(
            EventRequest(
                readStart: readStart,
                readCount: readEnd - readStart,
                detectedPeakOffset: peak - readStart,
                minimumWindowStart: Swift.max(
                    0, idealStart + DetectionConstants.filterWarmUpSamples - readStart)))
    }

    // MARK: Stages 2–3 — localisation, extraction, measurement

    /// Localises, extracts and measures a detected event (§23.4.1–§23.6).
    ///
    /// - Parameters:
    ///   - request: The request returned by ``detect(frame:startingAt:)``.
    ///   - samples: The raw samples of the requested range.
    ///   - timestamp: The timestamp recorded on any candidate.
    /// - Returns: The detection outcome for the event.
    public mutating func measure(
        _ request: EventRequest, samples: [Double], at timestamp: Date
    ) -> DetectionOutcome {
        precondition(samples.count == request.readCount, "sample count must match the request")
        let (outcome, windowEnd, eventPeak) = measureEvent(
            raw: samples,
            detectedPeakOffset: request.detectedPeakOffset,
            minimumWindowStart: request.minimumWindowStart,
            at: timestamp)
        extractedUntil = Swift.max(extractedUntil, request.readStart + windowEnd)
        lastEventPeak = eventPeak
        return outcome
    }

    /// Runs every stage on one self-contained frame.
    ///
    /// The frame is the whole observation: the event window is cut from it
    /// and, if the event runs past the frame's end, its decay is censored.
    ///
    /// - Parameters:
    ///   - frame: The frame's samples. Its count must equal ``frameSize``.
    ///   - timestamp: The frame's capture timestamp, recorded on any candidate.
    /// - Returns: The detection outcome for this frame.
    public mutating func process(frame: [Double], at timestamp: Date) -> DetectionOutcome {
        precondition(frame.count == frameSize, "frame length must equal frameSize")
        guard let (peakIndex, _) = detectedPeak(in: frame) else { return .noCandidate }
        return measureEvent(
            raw: frame, detectedPeakOffset: peakIndex, minimumWindowStart: 0, at: timestamp
        ).outcome
    }

    // MARK: Private

    /// Filters a frame and returns its peak index and magnitude if it is a
    /// candidate; otherwise updates the noise floor and returns `nil`.
    private mutating func detectedPeak(in frame: [Double]) -> (index: Int, magnitude: Double)? {
        precondition(frame.count == frameSize, "frame length must equal frameSize")
        let dcRemoved = SignalPreprocessing.removeDCOffset(frame)
        let filtered = filter.process(dcRemoved)

        guard detector.detectsCandidate(inFiltered: filtered) else {
            noiseFloor.update(withFrameRMS: TimeDomainFeatures.rmsEnergy(of: filtered))
            // Telemetry only; the decision above has already been made and is
            // unaffected. The peaks are computed solely when observed.
            if let observe = nonDetectionObserver {
                observe(
                    NonDetectionSample(
                        prefilterPeak: Self.peakMagnitude(of: dcRemoved),
                        filteredPeak: Self.peakMagnitude(of: filtered)))
            }
            return nil
        }
        let index = Self.peakIndex(of: filtered, in: 0..<filtered.count)
        return (index, abs(filtered[index]))
    }

    /// Localises the event in `raw`, cuts the event window and measures it.
    ///
    /// - Returns: The outcome, the window's end relative to `raw`, and the
    ///   event's filtered peak magnitude.
    private func measureEvent(
        raw: [Double], detectedPeakOffset: Int, minimumWindowStart: Int, at timestamp: Date
    ) -> (outcome: DetectionOutcome, windowEnd: Int, peak: Double) {
        let dcRemoved = SignalPreprocessing.removeDCOffset(raw)
        let filtered = filter.process(dcRemoved)

        // Peak: the detecting frame may hold only the start of the attack.
        let searchStart = Swift.max(
            minimumWindowStart, detectedPeakOffset - DetectionConstants.eventPreRollSamples)
        let searchEnd = Swift.min(
            filtered.count, detectedPeakOffset + DetectionConstants.maximumAttackSamples + 1)
        let peak = Self.peakIndex(of: filtered, in: searchStart..<searchEnd)

        // Onset: walk back while the attack stays above the onset fraction,
        // tolerating zero crossings but not a quiet gap.
        let threshold = FeatureConstants.attackOnsetThreshold * abs(filtered[peak])
        let lookBackLimit = Swift.max(
            minimumWindowStart, peak - DetectionConstants.maximumOnsetLookBackSamples)
        var onset = peak
        var index = peak - 1
        while index >= lookBackLimit, onset - index <= DetectionConstants.onsetGapSamples {
            if abs(filtered[index]) >= threshold { onset = index }
            index -= 1
        }

        let peakMagnitude = abs(filtered[peak])
        let windowStart = Swift.max(
            minimumWindowStart, onset - DetectionConstants.eventPreRollSamples)
        let windowEnd = Swift.min(filtered.count, windowStart + eventWindowSize)
        let window = Array(filtered[windowStart..<windowEnd])
        let measurement = pipeline.measure(
            eventWindow: window, noiseFloorRMS: noiseFloor.currentRMS)

        if let reason = validator.rejectionReason(
            dcRemovedWindow: Array(dcRemoved[windowStart..<windowEnd]),
            filteredWindow: window,
            decay: measurement.decay,
            noiseFloorRMS: noiseFloor.currentRMS
        ) {
            return (.rejected(reason), windowEnd, peakMagnitude)
        }
        guard let vector = measurement.featureVector, let decay = measurement.decay else {
            return (.rejected(.decayNotMeasurable), windowEnd, peakMagnitude)
        }
        guard vector.isValid else {
            return (.rejected(.invalidFeatureVector), windowEnd, peakMagnitude)
        }
        let telemetry = EventTelemetry(
            onsetOffsetSamples: onset - detectedPeakOffset,
            windowSamples: window.count,
            decay: decay)
        return (
            .candidate(
                Candidate(
                    featureVector: vector, detectedAt: timestamp, status: .validated,
                    event: telemetry)),
            windowEnd, peakMagnitude
        )
    }

    /// The largest absolute sample value, used for telemetry only.
    private static func peakMagnitude(of signal: [Double]) -> Double {
        signal.reduce(0.0) { Swift.max($0, abs($1)) }
    }

    /// The index of the largest magnitude in `range`; the earliest on ties.
    private static func peakIndex(of signal: [Double], in range: Range<Int>) -> Int {
        var best = range.lowerBound
        for index in range where abs(signal[index]) > abs(signal[best]) {
            best = index
        }
        return best
    }
}
