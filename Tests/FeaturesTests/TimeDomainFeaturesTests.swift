import XCTest

@testable import Features

final class TimeDomainFeaturesTests: XCTestCase {

    private let accuracy = 1e-12

    // MARK: Peak Amplitude

    func testPeakAmplitudeIsMaximumMagnitude() {
        XCTAssertEqual(
            TimeDomainFeatures.peakAmplitude(of: [0.2, -0.7, 0.3]), 0.7, accuracy: accuracy)
    }

    func testPeakAmplitudeOfEmptyIsZero() {
        XCTAssertEqual(TimeDomainFeatures.peakAmplitude(of: []), 0)
    }

    // MARK: RMS Energy

    func testRMSEnergy() {
        // sqrt((0.36 + 0.64) / 2) = sqrt(0.5).
        XCTAssertEqual(
            TimeDomainFeatures.rmsEnergy(of: [0.6, 0.8]), 0.5.squareRoot(), accuracy: accuracy)
    }

    func testRMSEnergyOfZeroSignalIsZero() {
        XCTAssertEqual(TimeDomainFeatures.rmsEnergy(of: [0, 0, 0]), 0)
    }

    func testRMSEnergyOfEmptyIsZero() {
        XCTAssertEqual(TimeDomainFeatures.rmsEnergy(of: []), 0)
    }

    // MARK: Zero Crossing Rate

    func testZeroCrossingRateCountsSignChangesPerSample() {
        // Three sign changes over four samples.
        XCTAssertEqual(
            TimeDomainFeatures.zeroCrossingRate(of: [1, -1, 1, -1]), 0.75, accuracy: accuracy)
    }

    func testZeroCrossingRateWithFewChanges() {
        // One sign change over four samples.
        XCTAssertEqual(
            TimeDomainFeatures.zeroCrossingRate(of: [1, 1, -1, -1]), 0.25, accuracy: accuracy)
    }

    func testZeroCrossingRateOfMonotonicSignalIsZero() {
        XCTAssertEqual(TimeDomainFeatures.zeroCrossingRate(of: [1, 2, 3]), 0)
    }

    func testZeroCrossingRateOfSingleSampleIsZero() {
        XCTAssertEqual(TimeDomainFeatures.zeroCrossingRate(of: [1]), 0)
    }
}
