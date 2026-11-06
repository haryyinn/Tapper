import XCTest

@testable import Audio

final class RollingAudioBufferTests: XCTestCase {

    func testDefaultCapacityIsImplementationDefault() {
        XCTAssertEqual(RollingAudioBuffer.defaultCapacity, 16_384)
        let buffer = RollingAudioBuffer()
        XCTAssertEqual(buffer.capacity, 16_384)
    }

    func testEmptyBufferHasNoSamples() {
        let buffer = RollingAudioBuffer(capacity: 8)
        XCTAssertEqual(buffer.availableSampleCount, 0)
        XCTAssertEqual(buffer.totalSamplesWritten, 0)
        XCTAssertEqual(buffer.lastWriteHostTime, 0)
        XCTAssertEqual(buffer.latestSamples(4), [])
    }

    func testWriteFewerThanCapacityRetainsAllSamples() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([1, 2, 3], hostTime: 100)
        XCTAssertEqual(buffer.availableSampleCount, 3)
        XCTAssertEqual(buffer.totalSamplesWritten, 3)
        XCTAssertEqual(buffer.latestSamples(3), [1, 2, 3])
        XCTAssertEqual(buffer.latestSamples(8), [1, 2, 3])
    }

    func testWriteExactlyCapacityRetainsEverything() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([1, 2, 3, 4], hostTime: 1)
        XCTAssertEqual(buffer.availableSampleCount, 4)
        XCTAssertEqual(buffer.latestSamples(4), [1, 2, 3, 4])
    }

    func testOverflowOverwritesOldestSamples() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([1, 2, 3, 4, 5, 6], hostTime: 1)
        XCTAssertEqual(buffer.availableSampleCount, 4)
        XCTAssertEqual(buffer.totalSamplesWritten, 6)
        XCTAssertEqual(buffer.latestSamples(4), [3, 4, 5, 6])
        XCTAssertEqual(buffer.latestSamples(2), [5, 6])
    }

    func testWrapAcrossMultipleWritesPreservesChronologicalOrder() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([1, 2, 3], hostTime: 1)
        buffer.write([4, 5], hostTime: 2)
        // Six-slot logical stream 1..5 into a 4-slot ring keeps the last four.
        XCTAssertEqual(buffer.availableSampleCount, 4)
        XCTAssertEqual(buffer.totalSamplesWritten, 5)
        XCTAssertEqual(buffer.latestSamples(4), [2, 3, 4, 5])
    }

    func testLatestSamplesClampsToAvailable() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([1, 2], hostTime: 1)
        XCTAssertEqual(buffer.latestSamples(100), [1, 2])
    }

    func testLatestSamplesZeroReturnsEmpty() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([1, 2, 3], hostTime: 1)
        XCTAssertEqual(buffer.latestSamples(0), [])
    }

    func testHostTimeReflectsMostRecentWrite() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([1], hostTime: 111)
        XCTAssertEqual(buffer.lastWriteHostTime, 111)
        buffer.write([2], hostTime: 222)
        XCTAssertEqual(buffer.lastWriteHostTime, 222)
    }

    func testResetClearsState() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([1, 2, 3, 4], hostTime: 5)
        buffer.reset()
        XCTAssertEqual(buffer.availableSampleCount, 0)
        XCTAssertEqual(buffer.totalSamplesWritten, 0)
        XCTAssertEqual(buffer.lastWriteHostTime, 0)
        XCTAssertEqual(buffer.latestSamples(4), [])
    }

    func testEmptyWriteIsIgnored() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([], hostTime: 9)
        XCTAssertEqual(buffer.availableSampleCount, 0)
        XCTAssertEqual(buffer.lastWriteHostTime, 0)
    }

    // MARK: Absolute-position reads (ADR-017)

    func testAbsoluteReadBeforeWrapReturnsRequestedRange() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([10, 11, 12, 13, 14], hostTime: 1)
        XCTAssertEqual(buffer.samples(from: 1, count: 3), [11, 12, 13])
        XCTAssertEqual(buffer.samples(from: 0, count: 5), [10, 11, 12, 13, 14])
        XCTAssertEqual(buffer.samples(from: 5, count: 0), [])
    }

    func testAbsoluteReadAfterWrapUsesStreamPositions() {
        let buffer = RollingAudioBuffer(capacity: 4)
        buffer.write([0, 1, 2, 3, 4, 5, 6], hostTime: 1)
        // Positions 3...6 are retained; 0...2 have been overwritten.
        XCTAssertEqual(buffer.samples(from: 3, count: 4), [3, 4, 5, 6])
        XCTAssertEqual(buffer.samples(from: 4, count: 2), [4, 5])
        XCTAssertNil(buffer.samples(from: 2, count: 2), "position 2 was overwritten")
    }

    func testAbsoluteReadOfUnwrittenSamplesIsNil() {
        let buffer = RollingAudioBuffer(capacity: 8)
        buffer.write([1, 2, 3], hostTime: 1)
        XCTAssertNil(buffer.samples(from: 2, count: 2), "position 3 is not written yet")
        XCTAssertNil(buffer.samples(from: -1, count: 1))
    }

    func testAbsoluteReadAgreesWithLatestSamples() {
        let buffer = RollingAudioBuffer(capacity: 5)
        buffer.write((0..<13).map(Float.init), hostTime: 1)
        XCTAssertEqual(buffer.samples(from: 9, count: 4), buffer.latestSamples(4))
    }
}
