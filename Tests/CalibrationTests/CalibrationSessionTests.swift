import Foundation
import XCTest

@testable import Calibration
@testable import Features

final class CalibrationSessionTests: XCTestCase {

    private let configuration = CalibrationConfiguration(
        samplesPerZone: 2, minimumRetainedSamples: 2, regularizationLambda: 1e-3,
        thresholdMultiplier: 2.0, ambiguityMargin: 0.5)

    private func makeSession() -> CalibrationSession {
        CalibrationSession(
            configuration: configuration, deviceIdentifier: "test-device", algorithmVersion: "1.0")
    }

    private func vector(_ seed: Double) -> FeatureVector {
        FeatureVector(
            peakAmplitude: 0.5, rmsEnergy: 0.3, spectralCentroid: 1500 + seed,
            spectralBandwidth: 800, spectralRollOff: 4000, dominantFrequency: 1200 + seed,
            zeroCrossingRate: 0.1, attackTime: 2, decayTime: 5, signalDuration: 10)
    }

    func testStartsIdleAndIgnoresSamplesBeforeBegin() {
        var session = makeSession()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.addSample(vector(0)), .notCollecting)
    }

    func testBeginStartsAtFirstZone() {
        var session = makeSession()
        session.begin()
        XCTAssertEqual(session.state, .collecting(zone: .topLeft, accepted: 0))
    }

    func testAcceptsValidSampleAndAdvancesZoneWhenFull() {
        var session = makeSession()
        session.begin()
        XCTAssertEqual(session.addSample(vector(0)), .accepted(zone: .topLeft, acceptedInZone: 1))
        XCTAssertEqual(session.state, .collecting(zone: .topLeft, accepted: 1))
        // Second sample fills the zone (samplesPerZone = 2) -> advance to topRight.
        XCTAssertEqual(session.addSample(vector(1)), .accepted(zone: .topLeft, acceptedInZone: 2))
        XCTAssertEqual(session.state, .collecting(zone: .topRight, accepted: 0))
    }

    func testRejectsInvalidSampleWithoutAdvancing() {
        var session = makeSession()
        session.begin()
        let invalid = FeatureVector(
            peakAmplitude: 1.5, rmsEnergy: 0.3, spectralCentroid: 1500, spectralBandwidth: 800,
            spectralRollOff: 4000, dominantFrequency: 1200, zeroCrossingRate: 0.1, attackTime: 2,
            decayTime: 5, signalDuration: 10)
        XCTAssertEqual(session.addSample(invalid), .rejectedInvalidFeatureVector)
        XCTAssertEqual(session.state, .collecting(zone: .topLeft, accepted: 0))
    }

    func testFillingAllZonesReachesReadyToGenerate() {
        var session = makeSession()
        session.begin()
        var seed = 0.0
        for _ in InteractionZone.calibratable {
            for _ in 0..<configuration.samplesPerZone {
                _ = session.addSample(vector(seed))
                seed += 1
            }
        }
        XCTAssertEqual(session.state, .readyToGenerate)
    }

    func testGenerateProfileProducesCompleteImmutableProfile() throws {
        var session = makeSession()
        session.begin()
        var seed = 0.0
        for _ in InteractionZone.calibratable {
            for _ in 0..<configuration.samplesPerZone {
                _ = session.addSample(vector(seed))
                seed += 1
            }
        }
        let profile = try session.generateProfile(createdAt: Date(timeIntervalSince1970: 100)).get()
        XCTAssertEqual(session.state, .completed)
        XCTAssertEqual(profile.zones.count, 4)
        XCTAssertEqual(profile.deviceIdentifier, "test-device")
        XCTAssertEqual(profile.configuration.regularizationLambda, 1e-3)
        XCTAssertEqual(profile.normalization.means.count, 10)
        XCTAssertNotNil(profile.profile(for: .bottomRight))
        XCTAssertNil(profile.profile(for: .unknown))
    }

    func testGenerateBeforeReadyFails() {
        var session = makeSession()
        session.begin()
        XCTAssertEqual(session.generateProfile(createdAt: Date()), .failure(.emptyDataset))
    }
}
