import Foundation
import XCTest

@testable import Detection
@testable import Features

final class CandidateTests: XCTestCase {

    private func makeVector() -> FeatureVector {
        FeatureVector(
            peakAmplitude: 0.8,
            rmsEnergy: 0.3,
            spectralCentroid: 1500,
            spectralBandwidth: 800,
            spectralRollOff: 4000,
            dominantFrequency: 1200,
            zeroCrossingRate: 0.1,
            attackTime: 2,
            decayTime: 5,
            signalDuration: 10
        )
    }

    func testWithStatusPreservesIdentityAndFeatures() {
        let detected = Candidate(
            featureVector: makeVector(),
            detectedAt: Date(timeIntervalSince1970: 10),
            status: .detected
        )
        let validated = detected.withStatus(.validated)
        XCTAssertEqual(validated.id, detected.id)
        XCTAssertEqual(validated.featureVector, detected.featureVector)
        XCTAssertEqual(validated.detectedAt, detected.detectedAt)
        XCTAssertEqual(validated.status, .validated)
        XCTAssertEqual(detected.status, .detected, "original value must be unchanged")
    }

    func testCandidatesWithDistinctIdsAreNotEqual() {
        let timestamp = Date(timeIntervalSince1970: 10)
        let first = Candidate(featureVector: makeVector(), detectedAt: timestamp, status: .detected)
        let second = Candidate(
            featureVector: makeVector(), detectedAt: timestamp, status: .detected)
        XCTAssertNotEqual(first, second)
    }
}
