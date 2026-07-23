import Foundation
import XCTest

@testable import Detection

final class TapDetectorTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920
    private let timestamp = Date(timeIntervalSince1970: 500)

    /// A quiet in-band ambient frame (peak ≈ 0.001, far below detection).
    private func noiseFrame() -> [Double] {
        (0..<frameSize).map {
            0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate)
        }
    }

    /// The verified synthetic tap: 2000 Hz decaying burst at amplitude 0.5
    /// (duration ≈ 18 ms, filtered peak ≈ 0.54, filtered RMS ≈ 0.11).
    private func tapFrame() -> [Double] {
        (0..<frameSize).map {
            0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    /// A sustained in-band tone active for the whole 40 ms window.
    private func sustainedFrame() -> [Double] {
        (0..<frameSize).map {
            0.3 * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    func testQuietFrameYieldsNoCandidateAndSeedsNoiseFloor() throws {
        var detector = try TapDetector.v1()
        XCTAssertNil(detector.currentNoiseFloorRMS)
        XCTAssertEqual(detector.process(frame: noiseFrame(), at: timestamp), .noCandidate)
        XCTAssertNotNil(detector.currentNoiseFloorRMS)
    }

    func testTapAfterNoiseProducesValidatedCandidate() throws {
        var detector = try TapDetector.v1()
        _ = detector.process(frame: noiseFrame(), at: timestamp)

        let outcome = detector.process(frame: tapFrame(), at: timestamp)
        guard case .candidate(let candidate) = outcome else {
            XCTFail("expected a candidate, got \(outcome)")
            return
        }
        XCTAssertEqual(candidate.status, .validated)
        XCTAssertEqual(candidate.detectedAt, timestamp)
        XCTAssertTrue(candidate.featureVector.isValid)
        XCTAssertEqual(candidate.featureVector.dominantFrequency, 2000, accuracy: 30)
    }

    func testTapWithoutNoiseFloorIsRejectedFailSafe() throws {
        var detector = try TapDetector.v1()
        XCTAssertEqual(
            detector.process(frame: tapFrame(), at: timestamp),
            .rejected(.snrBelowMinimum)
        )
    }

    func testClippedFrameIsRejected() throws {
        var detector = try TapDetector.v1()
        _ = detector.process(frame: noiseFrame(), at: timestamp)
        var frame = tapFrame()
        frame[10] = 1.0
        XCTAssertEqual(detector.process(frame: frame, at: timestamp), .rejected(.clipped))
    }

    func testSustainedToneIsRejectedForDuration() throws {
        var detector = try TapDetector.v1()
        _ = detector.process(frame: noiseFrame(), at: timestamp)
        XCTAssertEqual(
            detector.process(frame: sustainedFrame(), at: timestamp),
            .rejected(.durationAboveMaximum)
        )
    }

    func testCandidateFramesDoNotUpdateNoiseFloor() throws {
        var detector = try TapDetector.v1()
        _ = detector.process(frame: noiseFrame(), at: timestamp)
        let seeded = detector.currentNoiseFloorRMS
        _ = detector.process(frame: tapFrame(), at: timestamp)
        XCTAssertEqual(detector.currentNoiseFloorRMS, seeded)
    }

    func testDeterministicOutcomes() throws {
        var first = try TapDetector.v1()
        var second = try TapDetector.v1()
        for frame in [noiseFrame(), tapFrame(), sustainedFrame()] {
            XCTAssertEqual(
                first.process(frame: frame, at: timestamp),
                second.process(frame: frame, at: timestamp)
            )
        }
    }
}
