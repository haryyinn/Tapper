import XCTest

@testable import DSP

final class HannWindowTests: XCTestCase {

    private let accuracy = 1e-12

    func testCoefficientsZeroAtEndsAndOneAtCenter() {
        let window = HannWindow(size: 5)
        let result = window.apply(to: [1, 1, 1, 1, 1])
        // Symmetric Hann of length 5: [0, 0.5, 1, 0.5, 0].
        XCTAssertEqual(result.samples[0], 0, accuracy: accuracy)
        XCTAssertEqual(result.samples[1], 0.5, accuracy: accuracy)
        XCTAssertEqual(result.samples[2], 1, accuracy: accuracy)
        XCTAssertEqual(result.samples[3], 0.5, accuracy: accuracy)
        XCTAssertEqual(result.samples[4], 0, accuracy: accuracy)
    }

    func testApplyScalesSamples() {
        let window = HannWindow(size: 5)
        let result = window.apply(to: [2, 2, 2, 2, 2])
        XCTAssertEqual(result.samples, [0, 1, 2, 1, 0])
    }

    func testApplyProducesHannWindowMetadata() {
        let result = HannWindow(size: 4).apply(to: [1, 1, 1, 1])
        XCTAssertEqual(result.windowFunction, .hann)
        XCTAssertEqual(result.frameSize, 4)
        XCTAssertEqual(result.samples.count, 4)
    }

    func testSingleSampleWindowIsUnity() {
        let result = HannWindow(size: 1).apply(to: [3])
        XCTAssertEqual(result.samples, [3])
    }
}
