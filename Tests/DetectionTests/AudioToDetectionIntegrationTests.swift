import Foundation
import XCTest

@testable import Audio
@testable import Detection

/// Integration coverage for the Audio → Detection chain: synthetic samples flow
/// through the rolling buffer and the analysis-frame extractor into the tap
/// detector, using the same verified synthetic signals as the unit tests.
final class AudioToDetectionIntegrationTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920

    /// A quiet in-band noise segment (peak well below the detection threshold).
    private func noiseSegment() -> [Float] {
        (0..<frameSize).map { Float(0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate)) }
    }

    /// A 2000 Hz decaying tap segment beginning at sample 0.
    private func tapSegment() -> [Float] {
        (0..<frameSize).map {
            Float(
                0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate))
        }
    }

    func testSamplesFlowFromRingThroughExtractorToDetector() throws {
        // Build a stream of noise followed by a tap and store it in the ring.
        let stream = noiseSegment() + tapSegment()
        let ring = RollingAudioBuffer(capacity: 8192)
        ring.write(stream, hostTime: 0)

        let stored = ring.latestSamples(stream.count)
        XCTAssertEqual(stored, stream, "ring round-trip must preserve the samples")

        // Split into overlapping analysis frames: offsets 0, 960, 1920.
        let frames = AnalysisFrameExtractor.v1.frames(
            from: stored, startTimestamp: Date(timeIntervalSince1970: 0), sampleRate: sampleRate)
        XCTAssertEqual(frames.count, 3)

        var detector = try TapDetector.v1()

        // Frame 0 is pure noise: no candidate, and it seeds the noise floor.
        let noiseFrame = frames[0].samples.map(Double.init)
        XCTAssertEqual(detector.process(frame: noiseFrame, at: frames[0].timestamp), .noCandidate)
        XCTAssertNotNil(detector.currentNoiseFloorRMS)

        // The last frame (offset 1920) is the tap: it becomes a validated candidate.
        let tapFrame = frames[2].samples.map(Double.init)
        let outcome = detector.process(frame: tapFrame, at: frames[2].timestamp)
        guard case .candidate(let candidate) = outcome else {
            XCTFail("expected a candidate from the tap frame, got \(outcome)")
            return
        }
        XCTAssertEqual(candidate.status, .validated)
        XCTAssertTrue(candidate.featureVector.isValid)
        XCTAssertEqual(candidate.featureVector.dominantFrequency, 2000, accuracy: 30)
    }
}
