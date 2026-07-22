import XCTest

@testable import Features

final class FeatureVectorTests: XCTestCase {

    private func makeValid(
        peakAmplitude: Double = 0.8,
        rmsEnergy: Double = 0.3,
        spectralCentroid: Double = 1500,
        spectralBandwidth: Double = 800,
        spectralRollOff: Double = 4000,
        dominantFrequency: Double = 1200,
        zeroCrossingRate: Double = 0.1,
        attackTime: Double = 2,
        decayTime: Double = 5,
        signalDuration: Double = 10
    ) -> FeatureVector {
        FeatureVector(
            peakAmplitude: peakAmplitude,
            rmsEnergy: rmsEnergy,
            spectralCentroid: spectralCentroid,
            spectralBandwidth: spectralBandwidth,
            spectralRollOff: spectralRollOff,
            dominantFrequency: dominantFrequency,
            zeroCrossingRate: zeroCrossingRate,
            attackTime: attackTime,
            decayTime: decayTime,
            signalDuration: signalDuration
        )
    }

    func testValidVectorPasses() {
        XCTAssertNoThrow(try makeValid().validate())
        XCTAssertTrue(makeValid().isValid)
    }

    func testNonFiniteValueFails() {
        XCTAssertThrowsError(try makeValid(spectralCentroid: .nan).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .nonFiniteValue)
        }
    }

    func testAmplitudeOutOfRangeFails() {
        XCTAssertThrowsError(try makeValid(peakAmplitude: 1.5).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .amplitudeOutOfRange)
        }
        XCTAssertThrowsError(try makeValid(rmsEnergy: -0.1).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .amplitudeOutOfRange)
        }
    }

    func testNegativeSpectralValueFails() {
        XCTAssertThrowsError(try makeValid(spectralCentroid: -1).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .negativeSpectralValue)
        }
    }

    func testNegativeTemporalValueFails() {
        XCTAssertThrowsError(try makeValid(attackTime: -1).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .negativeTemporalValue)
        }
    }

    func testNonPositiveSignalDurationFails() {
        XCTAssertThrowsError(try makeValid(signalDuration: 0).validate()) { error in
            XCTAssertEqual(error as? FeatureVectorValidationError, .nonPositiveSignalDuration)
        }
    }
}
