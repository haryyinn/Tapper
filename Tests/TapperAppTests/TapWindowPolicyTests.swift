import XCTest

@testable import TapperApp

/// Tests the trial timing rule (Phase 0 of the measurement redesign plan).
///
/// Clock and sleep are injected, so these run in no real time and cannot be
/// flaky.
final class TapWindowPolicyTests: XCTestCase {

    /// A controllable clock: `sleep` advances it rather than suspending.
    ///
    /// Comparisons allow 1e-6: repeated `Date.addingTimeInterval` accumulates
    /// roughly 2.4e-8 per addition, so a tighter tolerance tests Foundation's
    /// arithmetic rather than this policy.
    private final class Clock {
        var now = Date(timeIntervalSince1970: 0)
        var slept: [TimeInterval] = []
        func advance(_ interval: TimeInterval) { now = now.addingTimeInterval(interval) }
        func sleep(_ interval: TimeInterval) {
            slept.append(interval)
            advance(interval)
        }
    }

    /// A tap heard immediately closes the window after the settle period, not
    /// after the full timeout.
    func testWindowClosesEarlyWhenAudioIsHeard() {
        let clock = Clock()
        let policy = TapWindowPolicy(timeout: 4.0, settle: 0.5)

        let closure = policy.wait(
            now: { clock.now }, heardAudio: { true }, isCancelled: { false },
            sleep: { clock.sleep($0) })

        XCTAssertEqual(closure, .heard)
        // Settle only: it did not wait out the timeout.
        XCTAssertEqual(clock.now.timeIntervalSince1970, 0.5, accuracy: 1e-6)
        XCTAssertEqual(clock.slept, [0.5])
    }

    /// Silence for the whole timeout is a genuine miss, and takes the full
    /// timeout to establish.
    func testWindowTimesOutWhenNothingIsHeard() {
        let clock = Clock()
        let policy = TapWindowPolicy(timeout: 1.0, settle: 0.5, poll: 0.1)

        let closure = policy.wait(
            now: { clock.now }, heardAudio: { false }, isCancelled: { false },
            sleep: { clock.sleep($0) })

        XCTAssertEqual(closure, .timedOut)
        XCTAssertEqual(clock.now.timeIntervalSince1970, 1.0, accuracy: 1e-6)
        XCTAssertEqual(clock.slept, [Double](repeating: 0.1, count: 10))
    }

    /// A tap arriving late — after the old 1.2 s window would have closed — is
    /// still heard. This is the case that was being recorded as a recognition
    /// failure.
    func testLateTapIsStillHeard() {
        let clock = Clock()
        let policy = TapWindowPolicy(timeout: 4.0, settle: 0.5, poll: 0.1)
        // Audio appears only once 2 s have elapsed.
        let heard = { clock.now.timeIntervalSince1970 >= 2.0 }

        let closure = policy.wait(
            now: { clock.now }, heardAudio: heard, isCancelled: { false },
            sleep: { clock.sleep($0) })

        XCTAssertEqual(closure, .heard)
        XCTAssertEqual(clock.now.timeIntervalSince1970, 2.5, accuracy: 1e-6)
    }

    /// Audio arriving inside the final poll interval is not lost to the
    /// deadline check.
    func testAudioArrivingAtTheDeadlineIsNotMissed() {
        let clock = Clock()
        let policy = TapWindowPolicy(timeout: 0.5, settle: 0.0, poll: 0.1)
        // Silent until the deadline has passed, then audible.
        let heard = { clock.now.timeIntervalSince1970 >= 0.5 }

        let closure = policy.wait(
            now: { clock.now }, heardAudio: heard, isCancelled: { false },
            sleep: { clock.sleep($0) })

        XCTAssertEqual(closure, .heard)
    }

    /// Cancellation is honoured promptly rather than at the timeout.
    func testCancellationStopsTheWait() {
        let clock = Clock()
        let policy = TapWindowPolicy(timeout: 10.0, settle: 0.5, poll: 0.1)

        let closure = policy.wait(
            now: { clock.now }, heardAudio: { false }, isCancelled: { true },
            sleep: { clock.sleep($0) })

        XCTAssertEqual(closure, .cancelled)
        XCTAssertEqual(clock.now.timeIntervalSince1970, 0.0, accuracy: 1e-12)
    }

    /// Degenerate inputs are clamped rather than causing a spin or a zero-length
    /// window.
    func testDegenerateParametersAreClamped() {
        let policy = TapWindowPolicy(timeout: -5, settle: -1, poll: 0)
        XCTAssertEqual(policy.timeout, 0.1, accuracy: 1e-12)
        XCTAssertEqual(policy.settle, 0.0, accuracy: 1e-12)
        XCTAssertEqual(policy.poll, 0.001, accuracy: 1e-12)
    }
}
