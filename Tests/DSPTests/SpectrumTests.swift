import XCTest

@testable import DSP

final class SpectrumTests: XCTestCase {

    func testFrequencyAxisFromFFTResult() {
        let fftResult = FFTResult(
            magnitudes: [1, 2, 3, 4],
            binCount: 4,
            frequencyResolution: 23.4375
        )
        let spectrum = Spectrum(fftResult: fftResult)
        XCTAssertEqual(spectrum.magnitudes, [1, 2, 3, 4])
        XCTAssertEqual(spectrum.frequencies, [0, 23.4375, 46.875, 70.3125])
    }

    func testFrequenciesAreMonotonicallyIncreasing() {
        let fftResult = FFTResult(
            magnitudes: [Double](repeating: 1, count: 100),
            binCount: 100,
            frequencyResolution: 23.4375
        )
        let spectrum = Spectrum(fftResult: fftResult)
        for index in 1..<spectrum.frequencies.count {
            XCTAssertGreaterThan(spectrum.frequencies[index], spectrum.frequencies[index - 1])
        }
    }
}
