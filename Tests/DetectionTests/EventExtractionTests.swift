import DSP
import Foundation
import XCTest

@testable import Detection
@testable import Features

/// Event-anchored measurement through the two-stage detector API
/// (`ALGORITHM` §23.4.1, ADR-017).
final class EventExtractionTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920
    private let hop = 960
    private let timestamp = Date(timeIntervalSince1970: 700)

    /// A tap: 1 ms attack, then a 700 Hz ring with time constant `tau`.
    private func tap(tauMilliseconds tau: Double = 8, amplitude: Double = 0.4) -> [Double] {
        (0..<9600).map { n in
            let t = Double(n) / sampleRate
            let envelope = t < 0.001 ? t / 0.001 : exp(-(t - 0.001) / (tau / 1000))
            return amplitude * envelope * sin(2 * Double.pi * 700 * t)
        }
    }

    private func quiet(_ count: Int) -> [Double] {
        (0..<count).map { 0.0005 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
    }

    /// Steps the detector through `stream` at fixed hops, as the runtime does,
    /// and returns every event outcome.
    private func events(in stream: [Double], detector: inout TapDetector) -> [DetectionOutcome] {
        var outcomes: [DetectionOutcome] = []
        var frameEnd = frameSize
        while frameEnd <= stream.count {
            let start = frameEnd - frameSize
            frameEnd += hop
            guard
                case .event(let request) = detector.detect(
                    frame: Array(stream[start..<(start + frameSize)]), startingAt: start),
                request.readEnd <= stream.count
            else { continue }
            outcomes.append(
                detector.measure(
                    request, samples: Array(stream[request.readStart..<request.readEnd]),
                    at: timestamp))
        }
        return outcomes
    }

    func testTapIsMeasuredOnceAndAccepted() throws {
        var detector = try TapDetector.v1()
        let outcomes = events(in: quiet(9600) + tap() + quiet(9600), detector: &detector)
        XCTAssertEqual(outcomes.count, 1, "one tap, one event")
        guard case .candidate(let candidate) = outcomes.first else {
            return XCTFail("expected a candidate, got \(outcomes)")
        }
        let event = try XCTUnwrap(candidate.event)
        XCTAssertEqual(event.windowSamples, DetectionConstants.eventWindowSamples)
        XCTAssertEqual(event.decay.timeConstantMilliseconds, 8, accuracy: 0.2)
    }

    func testFeaturesDoNotDependOnWhereTheTapFallsInTheFrame() throws {
        // The decisive regression of ADR-017: a physically identical tap must
        // measure the same wherever it lands relative to the frame grid.
        var vectors: [FeatureVector] = []
        for offset in stride(from: 0, to: frameSize, by: 191) {
            var detector = try TapDetector.v1()
            let outcomes = events(in: quiet(9600 + offset) + tap(), detector: &detector)
            guard case .candidate(let candidate) = outcomes.first else {
                return XCTFail("offset \(offset): \(outcomes)")
            }
            vectors.append(candidate.featureVector)
        }
        let reference = try XCTUnwrap(vectors.first)
        for vector in vectors {
            XCTAssertEqual(
                vector.signalDuration, reference.signalDuration,
                accuracy: reference.signalDuration * 0.01)
            XCTAssertEqual(
                vector.rmsEnergy, reference.rmsEnergy, accuracy: reference.rmsEnergy * 0.05)
            XCTAssertEqual(
                vector.spectralCentroid, reference.spectralCentroid,
                accuracy: reference.spectralCentroid * 0.05)
            XCTAssertEqual(
                vector.spectralBandwidth, reference.spectralBandwidth,
                accuracy: reference.spectralBandwidth * 0.05)
        }
    }

    func testLongRingIsNotCountedAsASecondTap() throws {
        // A 25 ms ring outlasts the 40 ms window and re-crosses the detection
        // threshold; it belongs to the first event.
        var detector = try TapDetector.v1()
        let outcomes = events(
            in: quiet(9600) + tap(tauMilliseconds: 25, amplitude: 0.6) + quiet(9600),
            detector: &detector)
        XCTAssertEqual(outcomes.count, 1)
        guard case .candidate(let candidate) = outcomes.first else {
            return XCTFail("expected a candidate, got \(outcomes)")
        }
        XCTAssertTrue(try XCTUnwrap(candidate.event).decay.isCensored)
    }

    func testSecondTapAfterRefractoryIsDetected() throws {
        var detector = try TapDetector.v1()
        let outcomes = events(
            in: quiet(9600) + tap() + quiet(4800) + tap() + quiet(9600), detector: &detector)
        XCTAssertEqual(outcomes.count, 2)
        for outcome in outcomes {
            guard case .candidate = outcome else { return XCTFail("expected candidates") }
        }
    }

    func testDetectingFrameNeverUpdatesTheNoiseFloor() throws {
        var detector = try TapDetector.v1()
        XCTAssertEqual(detector.detect(frame: quiet(frameSize), startingAt: 0), .noCandidate)
        let seeded = detector.currentNoiseFloorRMS
        let step = detector.detect(frame: Array(tap().prefix(frameSize)), startingAt: frameSize)
        guard case .event = step else { return XCTFail("expected an event, got \(step)") }
        XCTAssertEqual(detector.currentNoiseFloorRMS, seeded)
    }
}

final class EventStatisticsTests: XCTestCase {

    private func event(tau: Double, censored: Bool, onset: Int) -> (EventTelemetry, FeatureVector) {
        (
            EventTelemetry(
                onsetOffsetSamples: onset, windowSamples: 1920,
                decay: DecayEstimate(
                    timeConstantMilliseconds: tau, fitRangeDB: 20,
                    coefficientOfDetermination: 0.995, pointCount: 20, isCensored: censored)),
            FeatureVector(
                peakAmplitude: 0.4, rmsEnergy: 0.1, spectralCentroid: 700,
                spectralBandwidth: 50, spectralRollOff: 800, dominantFrequency: 700,
                zeroCrossingRate: 0.03, attackTime: 1, decayTime: tau / 10,
                signalDuration: tau * log(10.0))
        )
    }

    func testSummarisesDecayCensoringAndCorrelation() throws {
        let stats = try XCTUnwrap(
            EventStatistics.make(from: [
                event(tau: 4, censored: false, onset: -10),
                event(tau: 6, censored: true, onset: -20),
                event(tau: 8, censored: false, onset: -30),
            ]))
        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats.medianTimeConstantMilliseconds, 6, accuracy: 1e-12)
        XCTAssertEqual(stats.censoredFraction, 1.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(stats.highConfidenceFraction, 1, accuracy: 1e-12)
        XCTAssertEqual(stats.medianOnsetOffsetSamples, -20, accuracy: 1e-12)
        // Slots 8 and 9 are both linear in τ here: perfectly collinear.
        XCTAssertEqual(try XCTUnwrap(stats.decayDurationCorrelation), 1, accuracy: 1e-12)
    }

    func testNoEventsYieldsNil() {
        XCTAssertNil(EventStatistics.make(from: []))
    }
}
