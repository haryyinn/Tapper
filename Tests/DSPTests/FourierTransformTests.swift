import XCTest

@testable import DSP

final class FourierTransformTests: XCTestCase {

    private let size = 2048
    private let sampleRate = 48_000.0

    private func sinusoid(hz: Double, count: Int) -> [Double] {
        (0..<count).map { sin(2 * Double.pi * hz * Double($0) / sampleRate) }
    }

    private func peakBin(_ magnitudes: [Double]) -> Int {
        magnitudes.enumerated().max(by: { $0.element < $1.element })!.offset
    }

    func testBinCountAndResolution() throws {
        let fft = try FourierTransform(size: size, sampleRate: sampleRate)
        let result = fft.magnitudeSpectrum(of: sinusoid(hz: 3000, count: size))
        XCTAssertEqual(result.binCount, 1025)
        XCTAssertEqual(result.magnitudes.count, 1025)
        XCTAssertEqual(result.frequencyResolution, 23.4375, accuracy: 1e-9)
    }

    func testSinusoidPeaksAtExpectedBin() throws {
        let fft = try FourierTransform(size: size, sampleRate: sampleRate)
        // 3000 Hz -> bin 3000 / 23.4375 = 128; 6000 Hz -> bin 256.
        XCTAssertEqual(
            peakBin(fft.magnitudeSpectrum(of: sinusoid(hz: 3000, count: size)).magnitudes), 128)
        XCTAssertEqual(
            peakBin(fft.magnitudeSpectrum(of: sinusoid(hz: 6000, count: size)).magnitudes), 256)
    }

    func testShorterInputIsZeroPadded() throws {
        let fft = try FourierTransform(size: size, sampleRate: sampleRate)
        // A 1920-sample 4000 Hz tone, zero-padded to 2048, resolves near bin 171.
        let result = fft.magnitudeSpectrum(of: sinusoid(hz: 4000, count: 1920))
        XCTAssertEqual(result.magnitudes.count, 1025)
        let expectedBin = Int((4000.0 * Double(size) / sampleRate).rounded())
        XCTAssertLessThanOrEqual(abs(peakBin(result.magnitudes) - expectedBin), 1)
    }

    func testConstantSignalConcentratesEnergyAtDC() throws {
        let fft = try FourierTransform(size: size, sampleRate: sampleRate)
        let result = fft.magnitudeSpectrum(of: [Double](repeating: 1, count: size))
        XCTAssertEqual(peakBin(result.magnitudes), 0)
        XCTAssertGreaterThan(result.magnitudes[0], result.magnitudes[1])
    }

    func testDeterministicOutput() throws {
        let fft = try FourierTransform(size: size, sampleRate: sampleRate)
        let signal = sinusoid(hz: 1500, count: size)
        XCTAssertEqual(
            fft.magnitudeSpectrum(of: signal).magnitudes,
            fft.magnitudeSpectrum(of: signal).magnitudes
        )
    }
}
