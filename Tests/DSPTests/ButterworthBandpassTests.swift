import XCTest

@testable import DSP

final class ButterworthBandpassTests: XCTestCase {

    private let filter = ButterworthBandpass.v1
    private let centerHz = (300.0 * 6000.0).squareRoot()  // ≈ 1341.64 Hz

    // MARK: Frequency response

    func testUnityGainAtGeometricCenter() {
        XCTAssertEqual(filter.magnitudeResponse(atHz: centerHz), 1.0, accuracy: 1e-6)
    }

    func testMinusThreeDecibelAtCutoffs() {
        let minus3dB = 1.0 / 2.0.squareRoot()  // ≈ 0.70711
        XCTAssertEqual(filter.magnitudeResponse(atHz: 300), minus3dB, accuracy: 1e-4)
        XCTAssertEqual(filter.magnitudeResponse(atHz: 6000), minus3dB, accuracy: 1e-4)
    }

    func testDCAndNyquistFullyRejected() {
        XCTAssertEqual(filter.magnitudeResponse(atHz: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(filter.magnitudeResponse(atHz: 24_000), 0, accuracy: 1e-9)
    }

    func testStopbandIsAttenuated() {
        XCTAssertLessThan(filter.magnitudeResponse(atHz: 50), 0.05)
        XCTAssertLessThan(filter.magnitudeResponse(atHz: 20_000), 0.05)
    }

    func testPassbandIsNotAttenuated() {
        XCTAssertGreaterThan(filter.magnitudeResponse(atHz: 600), 0.9)
        XCTAssertGreaterThan(filter.magnitudeResponse(atHz: 3000), 0.9)
    }

    func testResponseIsHigherInBandThanOutOfBand() {
        let inBand = filter.magnitudeResponse(atHz: centerHz)
        XCTAssertGreaterThan(inBand, filter.magnitudeResponse(atHz: 100))
        XCTAssertGreaterThan(inBand, filter.magnitudeResponse(atHz: 12_000))
    }

    // MARK: Time-domain behavior

    func testDeterministicOutput() {
        let input = (0..<512).map { sin(2 * Double.pi * 1500 * Double($0) / 48_000) }
        XCTAssertEqual(filter.process(input), filter.process(input))
    }

    func testImpulseResponseIsStableAndDecays() {
        var impulse = [Double](repeating: 0, count: 4096)
        impulse[0] = 1
        let response = filter.process(impulse)
        XCTAssertTrue(response.allSatisfy(\.isFinite))
        let tail = abs(response[response.count - 1])
        XCTAssertLessThan(tail, 1e-9)
    }

    func testConstantInputIsRejectedInSteadyState() {
        let dc = [Double](repeating: 1.0, count: 2048)
        let output = filter.process(dc)
        XCTAssertLessThan(abs(output[output.count - 1]), 1e-6)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(filter.process([]), [])
    }
}
