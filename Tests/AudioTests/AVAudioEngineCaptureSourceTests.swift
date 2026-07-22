import XCTest

@testable import Audio

/// These tests avoid starting the engine, since a live microphone and
/// authorization are unavailable in CI. Capture behavior is validated through
/// the ``AudioCaptureSource`` protocol using an in-test fake (see
/// `AudioCaptureSourceTests`); here we only verify construction and the
/// device-availability query.
final class AVAudioEngineCaptureSourceTests: XCTestCase {

    func testNewSourceIsNotRunning() {
        let source = AVAudioEngineCaptureSource(buffer: RollingAudioBuffer(capacity: 8))
        XCTAssertFalse(source.isRunning)
    }

    func testAudioInputAvailabilityIsQueryable() {
        // Evaluating availability must not crash. The value is host-dependent
        // (false on a headless CI runner, true on a Mac with a microphone), so
        // only the fact that it can be queried is asserted.
        _ = AudioDeviceMonitor.isAudioInputAvailable
    }
}
