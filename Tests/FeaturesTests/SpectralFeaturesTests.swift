import XCTest

@testable import DSP
@testable import Features

final class SpectralFeaturesTests: XCTestCase {

    private let accuracy = 1e-12

    // MARK: Spectral Centroid

    func testSpectralCentroidIsMagnitudeWeightedMean() {
        let spectrum = Spectrum(frequencies: [0, 1, 2, 3], magnitudes: [0, 1, 1, 0])
        // (0·0 + 1·1 + 2·1 + 3·0) / (0 + 1 + 1 + 0) = 1.5.
        XCTAssertEqual(SpectralFeatures.spectralCentroid(spectrum), 1.5, accuracy: accuracy)
    }

    func testSpectralCentroidOfEmptyEnergyIsZero() {
        let spectrum = Spectrum(frequencies: [0, 1, 2], magnitudes: [0, 0, 0])
        XCTAssertEqual(SpectralFeatures.spectralCentroid(spectrum), 0)
    }

    // MARK: Spectral Bandwidth

    func testSpectralBandwidthIsWeightedSpread() {
        let spectrum = Spectrum(frequencies: [0, 1, 2, 3], magnitudes: [0, 1, 1, 0])
        // variance = (0.25·1 + 0.25·1) / 2 = 0.25 -> sqrt = 0.5.
        let bandwidth = SpectralFeatures.spectralBandwidth(spectrum, centroid: 1.5)
        XCTAssertEqual(bandwidth, 0.5, accuracy: accuracy)
    }

    // MARK: Spectral Roll-off (energy = magnitude squared)

    func testSpectralRollOffAtDefaultFraction() {
        let spectrum = Spectrum(frequencies: [0, 1, 2, 3], magnitudes: [1, 1, 1, 1])
        // energies [1,1,1,1], total 4, 85% target 3.4; cumulative reaches it at bin 3.
        XCTAssertEqual(SpectralFeatures.spectralRollOff(spectrum), 3)
    }

    func testSpectralRollOffWithFrontLoadedEnergy() {
        let spectrum = Spectrum(frequencies: [0, 1, 2, 3], magnitudes: [2, 1, 1, 0])
        // energies [4,1,1,0], total 6, 85% target 5.1; cumulative reaches it at bin 2.
        XCTAssertEqual(SpectralFeatures.spectralRollOff(spectrum), 2)
    }

    func testSpectralRollOffOfEmptyEnergyIsZero() {
        let spectrum = Spectrum(frequencies: [0, 1, 2], magnitudes: [0, 0, 0])
        XCTAssertEqual(SpectralFeatures.spectralRollOff(spectrum), 0)
    }

    // MARK: Dominant Frequency

    func testDominantFrequencyIsPeakBin() {
        let spectrum = Spectrum(frequencies: [0, 1, 2, 3], magnitudes: [0.1, 0.5, 0.2, 0.1])
        XCTAssertEqual(SpectralFeatures.dominantFrequency(spectrum), 1)
    }
}
