import Foundation
import XCTest

@testable import Audio

final class AnalysisFrameExtractorTests: XCTestCase {

    func testProducesOverlappingFrames() {
        let extractor = AnalysisFrameExtractor(frameSize: 4, hopSize: 2)
        let samples: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        let frames = extractor.frames(
            from: samples,
            startTimestamp: Date(timeIntervalSince1970: 0),
            sampleRate: 1000
        )
        // Offsets 0, 2, 4, 6 each fit a 4-sample frame within 10 samples.
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[0].samples, [0, 1, 2, 3])
        XCTAssertEqual(frames[1].samples, [2, 3, 4, 5])  // 50% overlap
        XCTAssertEqual(frames[3].samples, [6, 7, 8, 9])
        XCTAssertTrue(frames.allSatisfy { $0.frameSize == 4 })
    }

    func testFrameTimestampsAdvanceByHop() {
        let extractor = AnalysisFrameExtractor(frameSize: 4, hopSize: 2)
        let samples = [Float](repeating: 0, count: 10)
        let base = Date(timeIntervalSince1970: 100)
        let frames = extractor.frames(from: samples, startTimestamp: base, sampleRate: 1000)
        // Frame 1 begins two samples in; at 1000 Hz that is +0.002 s.
        XCTAssertEqual(frames[1].timestamp.timeIntervalSince1970, 100.002, accuracy: 1e-9)
    }

    func testBufferShorterThanFrameYieldsNoFrames() {
        let extractor = AnalysisFrameExtractor(frameSize: 4, hopSize: 2)
        let frames = extractor.frames(from: [1, 2, 3], startTimestamp: Date(), sampleRate: 1000)
        XCTAssertTrue(frames.isEmpty)
    }

    func testV1UsesSpecifiedWindowing() {
        XCTAssertEqual(AnalysisFrameExtractor.v1.frameSize, 1920)
        XCTAssertEqual(AnalysisFrameExtractor.v1.hopSize, 960)
    }
}
