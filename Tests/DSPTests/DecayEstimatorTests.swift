import XCTest

@testable import DSP

final class DecayEstimatorTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let estimator = DecayEstimator()

    /// An exponentially decaying 700 Hz tone with time constant `tau`, plus
    /// deterministic pseudo-random noise of RMS `noise`.
    private func ring(tauMilliseconds tau: Double, length: Int, noise: Double = 0) -> [Double] {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        return (0..<length).map { n in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let uniform = Double(state >> 11) / Double(1 << 53) - 0.5
            let t = Double(n) / sampleRate
            return 0.5 * exp(-t / (tau / 1000)) * sin(2 * Double.pi * 700 * t)
                + noise * uniform * 12.0.squareRoot()
        }
    }

    func testRecoversTimeConstantAcrossTheMeasurableRange() throws {
        // §14.13 verification: within ±2% for 2 ms ≤ τ ≤ 40 ms.
        for tau in [2.0, 5.0, 10.0, 20.0, 40.0] {
            let signal = ring(tauMilliseconds: tau, length: 24_000)
            let estimate = try XCTUnwrap(
                estimator.estimate(signal, sampleRate: sampleRate, noiseFloorRMS: nil))
            XCTAssertEqual(
                estimate.timeConstantMilliseconds, tau, accuracy: tau * 0.02, "τ = \(tau) ms")
            XCTAssertFalse(estimate.isCensored, "τ = \(tau) ms fits within the window")
            XCTAssertEqual(
                estimate.durationMilliseconds, estimate.timeConstantMilliseconds * log(10.0),
                accuracy: 1e-12)
        }
    }

    func testTruncatedDecayIsCensoredButUnbiased() throws {
        // A 40 ms window cannot show 25 dB of a τ = 20 ms decay, but the slope
        // it does show still identifies τ (§14.13.5).
        let estimate = try XCTUnwrap(
            estimator.estimate(
                ring(tauMilliseconds: 20, length: 1920), sampleRate: sampleRate,
                noiseFloorRMS: nil))
        XCTAssertTrue(estimate.isCensored)
        XCTAssertLessThan(estimate.fitRangeDB, 20)
        XCTAssertEqual(estimate.timeConstantMilliseconds, 20, accuracy: 0.4)
    }

    func testNoiseFloorBoundsTheFitAndCensors() throws {
        let signal = ring(tauMilliseconds: 10, length: 9600, noise: 0.002)
        let estimate = try XCTUnwrap(
            estimator.estimate(signal, sampleRate: sampleRate, noiseFloorRMS: 0.002))
        XCTAssertEqual(estimate.timeConstantMilliseconds, 10, accuracy: 0.5)
        // Peak ≈ −9 dBFS, floor + 5 dB ≈ −49 dBFS: the −25 dB target is reached
        // first, so this is not censored.
        XCTAssertFalse(estimate.isCensored)

        let loud = try XCTUnwrap(
            estimator.estimate(signal, sampleRate: sampleRate, noiseFloorRMS: 0.03))
        XCTAssertTrue(loud.isCensored, "decay meets a high noise floor before −25 dB")
    }

    func testDeclinesOnSustainedTone() {
        let tone = (0..<1920).map { 0.3 * sin(2 * Double.pi * 700 * Double($0) / sampleRate) }
        XCTAssertNil(estimator.estimate(tone, sampleRate: sampleRate, noiseFloorRMS: nil))
    }

    func testDeclinesOnSilenceAndShortInput() {
        XCTAssertNil(
            estimator.estimate(
                [Double](repeating: 0, count: 1920), sampleRate: sampleRate, noiseFloorRMS: nil))
        XCTAssertNil(estimator.estimate([0.1, 0.2], sampleRate: sampleRate, noiseFloorRMS: nil))
    }

    func testClippedAttackDoesNotChangeTheEstimate() throws {
        // The fit starts 5 dB below the peak, so flattening the top 3 dB of the
        // attack leaves the decay estimate essentially unchanged (§14.13.2).
        let signal = ring(tauMilliseconds: 10, length: 9600)
        let ceiling = 0.5 * pow(10, -3.0 / 20)
        let clipped = signal.map { Swift.max(-ceiling, Swift.min(ceiling, $0)) }
        let clean = try XCTUnwrap(
            estimator.estimate(signal, sampleRate: sampleRate, noiseFloorRMS: nil))
        let flattened = try XCTUnwrap(
            estimator.estimate(clipped, sampleRate: sampleRate, noiseFloorRMS: nil))
        XCTAssertEqual(
            flattened.timeConstantMilliseconds, clean.timeConstantMilliseconds,
            accuracy: clean.timeConstantMilliseconds * 0.03)
    }

    func testCleanDecayIsHighConfidence() throws {
        let estimate = try XCTUnwrap(
            estimator.estimate(
                ring(tauMilliseconds: 8, length: 4800), sampleRate: sampleRate,
                noiseFloorRMS: nil))
        XCTAssertTrue(estimate.isHighConfidence)
        XCTAssertGreaterThanOrEqual(estimate.coefficientOfDetermination, 0.99)
    }
}
