import AVFoundation
import XCTest
import os

@testable import Audio

/// A substitute capture source used to exercise the acquisition flow without a
/// live microphone. Samples are delivered explicitly by the test via
/// ``deliver(_:hostTime:)``.
private final class FakeAudioCaptureSource: AudioCaptureSource {

    private let buffer: RollingAudioBuffer
    private let running = OSAllocatedUnfairLock(initialState: false)

    init(buffer: RollingAudioBuffer) {
        self.buffer = buffer
    }

    var isRunning: Bool { running.withLock { $0 } }

    func start() throws { running.withLock { $0 = true } }

    func stop() { running.withLock { $0 = false } }

    /// Simulates the audio thread delivering samples while running.
    func deliver(_ samples: [Float], hostTime: UInt64) {
        guard isRunning else { return }
        buffer.write(samples, hostTime: hostTime)
    }
}

final class AudioCaptureSourceTests: XCTestCase {

    func testSourceIsNotRunningInitially() {
        let source = FakeAudioCaptureSource(buffer: RollingAudioBuffer(capacity: 8))
        XCTAssertFalse(source.isRunning)
    }

    func testStartEnablesDeliveryIntoBuffer() throws {
        let buffer = RollingAudioBuffer(capacity: 8)
        let source = FakeAudioCaptureSource(buffer: buffer)

        try source.start()
        XCTAssertTrue(source.isRunning)

        source.deliver([1, 2, 3], hostTime: 42)
        XCTAssertEqual(buffer.latestSamples(3), [1, 2, 3])
        XCTAssertEqual(buffer.lastWriteHostTime, 42)
    }

    func testStopHaltsDelivery() throws {
        let buffer = RollingAudioBuffer(capacity: 8)
        let source = FakeAudioCaptureSource(buffer: buffer)

        try source.start()
        source.stop()
        XCTAssertFalse(source.isRunning)

        source.deliver([1, 2, 3], hostTime: 42)
        XCTAssertEqual(buffer.availableSampleCount, 0)
    }
}

final class MicrophoneAuthorizationStatusTests: XCTestCase {

    func testMapsPlatformStatuses() {
        XCTAssertEqual(MicrophoneAuthorizationStatus(.notDetermined), .notDetermined)
        XCTAssertEqual(MicrophoneAuthorizationStatus(.authorized), .authorized)
        XCTAssertEqual(MicrophoneAuthorizationStatus(.denied), .denied)
        XCTAssertEqual(MicrophoneAuthorizationStatus(.restricted), .restricted)
    }

    func testOnlyAuthorizedAllowsCapture() {
        XCTAssertTrue(MicrophoneAuthorizationStatus.authorized.allowsCapture)
        XCTAssertFalse(MicrophoneAuthorizationStatus.notDetermined.allowsCapture)
        XCTAssertFalse(MicrophoneAuthorizationStatus.denied.allowsCapture)
        XCTAssertFalse(MicrophoneAuthorizationStatus.restricted.allowsCapture)
    }
}
