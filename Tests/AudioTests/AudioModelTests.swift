import Foundation
import XCTest

@testable import Audio

final class AudioModelTests: XCTestCase {

    // MARK: CaptureConfiguration

    func testV1CaptureConfigurationMatchesSpecification() {
        let config = CaptureConfiguration.v1
        XCTAssertEqual(config.sampleRate, 48_000)
        XCTAssertEqual(config.channelCount, 1)
    }

    // MARK: AudioBuffer validation

    func testValidBufferPassesValidation() throws {
        let buffer = AudioBuffer(
            samples: [0.0, 0.5, -0.5, 1.0, -1.0],
            sampleRate: 48_000,
            channelCount: 1,
            timestamp: Date()
        )
        XCTAssertNoThrow(try buffer.validate())
        XCTAssertTrue(buffer.isValid)
    }

    func testEmptySamplesFailValidation() {
        let buffer = AudioBuffer(
            samples: [],
            sampleRate: 48_000,
            channelCount: 1,
            timestamp: Date()
        )
        XCTAssertFalse(buffer.isValid)
        XCTAssertThrowsError(try buffer.validate()) { error in
            XCTAssertEqual(error as? AudioBufferValidationError, .emptySamples)
        }
    }

    func testNonPositiveSampleRateFailsValidation() {
        let buffer = AudioBuffer(
            samples: [0.1, 0.2],
            sampleRate: 0,
            channelCount: 1,
            timestamp: Date()
        )
        XCTAssertThrowsError(try buffer.validate()) { error in
            XCTAssertEqual(error as? AudioBufferValidationError, .nonPositiveSampleRate)
        }
    }

    func testInvalidChannelCountFailsValidation() {
        let buffer = AudioBuffer(
            samples: [0.1, 0.2],
            sampleRate: 48_000,
            channelCount: 0,
            timestamp: Date()
        )
        XCTAssertThrowsError(try buffer.validate()) { error in
            XCTAssertEqual(error as? AudioBufferValidationError, .invalidChannelCount)
        }
    }

    func testNaNSampleFailsValidation() {
        let buffer = AudioBuffer(
            samples: [0.1, .nan, 0.2],
            sampleRate: 48_000,
            channelCount: 1,
            timestamp: Date()
        )
        XCTAssertThrowsError(try buffer.validate()) { error in
            XCTAssertEqual(error as? AudioBufferValidationError, .nonFiniteSample)
        }
    }

    func testInfiniteSampleFailsValidation() {
        let buffer = AudioBuffer(
            samples: [0.1, .infinity],
            sampleRate: 48_000,
            channelCount: 1,
            timestamp: Date()
        )
        XCTAssertThrowsError(try buffer.validate()) { error in
            XCTAssertEqual(error as? AudioBufferValidationError, .nonFiniteSample)
        }
    }

    // MARK: AudioMetadata

    func testAudioMetadataStoresValues() {
        let now = Date()
        let metadata = AudioMetadata(
            inputDevice: "Built-in Microphone",
            sampleRate: 48_000,
            channelCount: 1,
            bitDepth: 32,
            captureTimestamp: now
        )
        XCTAssertEqual(metadata.inputDevice, "Built-in Microphone")
        XCTAssertEqual(metadata.sampleRate, 48_000)
        XCTAssertEqual(metadata.channelCount, 1)
        XCTAssertEqual(metadata.bitDepth, 32)
        XCTAssertEqual(metadata.captureTimestamp, now)
    }
}
