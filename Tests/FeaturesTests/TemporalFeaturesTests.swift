import XCTest

@testable import Features

final class TemporalFeaturesTests: XCTestCase {

    private let accuracy = 1e-9
    // At 1000 Hz, one sample is one millisecond, making the expected values easy
    // to reason about.
    private let sampleRate = 1000.0
    // Peak at index 5; magnitudes reach 0.10 at index 2 and last do so at index 7.
    private let tap: [Double] = [0, 0.05, 0.2, 0.5, 0.8, 1.0, 0.6, 0.1, 0.05, 0]

    func testAttackTimeFromOnsetToPeak() {
        // onset index 2 -> peak index 5 = 3 ms.
        XCTAssertEqual(
            TimeDomainFeatures.attackTime(of: tap, sampleRate: sampleRate), 3, accuracy: accuracy)
    }

    func testDecayTimeFromPeakToOffset() {
        // peak index 5 -> first magnitude below 0.10 at index 8 = 3 ms.
        XCTAssertEqual(
            TimeDomainFeatures.decayTime(of: tap, sampleRate: sampleRate), 3, accuracy: accuracy)
    }

    func testSignalDurationSpansActiveSamples() {
        // first active index 2 -> last active index 7 = 5 ms.
        XCTAssertEqual(
            TimeDomainFeatures.signalDuration(of: tap, sampleRate: sampleRate), 5,
            accuracy: accuracy)
    }

    func testAttackTimeIsZeroWhenNeverReachesThreshold() {
        XCTAssertEqual(TimeDomainFeatures.attackTime(of: [0.05, 0.05], sampleRate: sampleRate), 0)
    }

    func testDecayTimeIsZeroWhenPeakIsLastSample() {
        XCTAssertEqual(TimeDomainFeatures.decayTime(of: [0.05, 1.0], sampleRate: sampleRate), 0)
    }

    func testSignalDurationIsZeroWhenNoActiveSamples() {
        XCTAssertEqual(
            TimeDomainFeatures.signalDuration(of: [0.01, 0.02], sampleRate: sampleRate), 0)
    }

    func testTemporalFeaturesAreZeroForEmptySignal() {
        XCTAssertEqual(TimeDomainFeatures.attackTime(of: [], sampleRate: sampleRate), 0)
        XCTAssertEqual(TimeDomainFeatures.decayTime(of: [], sampleRate: sampleRate), 0)
        XCTAssertEqual(TimeDomainFeatures.signalDuration(of: [], sampleRate: sampleRate), 0)
    }
}
