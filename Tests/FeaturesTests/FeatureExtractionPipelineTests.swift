import Foundation
import XCTest

@testable import Features

final class FeatureExtractionPipelineTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920

    /// A synthetic 2000 Hz decaying tap at amplitude 0.5.
    private func syntheticTap() -> [Double] {
        (0..<frameSize).map {
            0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    func testExtractsValidVectorFromTap() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let vector = try XCTUnwrap(pipeline.extract(from: syntheticTap()))
        XCTAssertNoThrow(try vector.validate())
        XCTAssertGreaterThan(vector.peakAmplitude, 0)
        XCTAssertLessThanOrEqual(vector.peakAmplitude, 1)
        XCTAssertGreaterThan(vector.signalDuration, 0)
        XCTAssertGreaterThanOrEqual(vector.attackTime, 0)
    }

    func testDominantFrequencyMatchesTapTone() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let vector = try XCTUnwrap(pipeline.extract(from: syntheticTap()))
        // 2000 Hz tone resolves to the nearest bin (~1992 Hz).
        XCTAssertEqual(vector.dominantFrequency, 2000, accuracy: 30)
    }

    func testClippedFrameIsRejected() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        var frame = syntheticTap()
        frame[10] = 1.0  // full-scale clip
        XCTAssertNil(pipeline.extract(from: frame))
    }

    func testDeterministicOutput() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let tap = syntheticTap()
        XCTAssertEqual(pipeline.extract(from: tap), pipeline.extract(from: tap))
    }
}
