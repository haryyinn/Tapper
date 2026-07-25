import Foundation
import XCTest

@testable import Audio
@testable import Calibration
@testable import Detection
@testable import Features
@testable import Runtime

final class CalibrationCoordinatorTests: XCTestCase {

    private let configuration = CalibrationConfiguration(
        samplesPerZone: 3, minimumRetainedSamples: 3, regularizationLambda: 1e-3,
        thresholdMultiplier: 2.0, ambiguityMargin: 0.5)

    private func makeCoordinator() throws -> CalibrationCoordinator {
        CalibrationCoordinator(
            session: CalibrationSession(
                configuration: configuration, deviceIdentifier: "test", algorithmVersion: "1.0"),
            detector: try TapDetector.v1(),
            buffer: RollingAudioBuffer(capacity: 8_192),
            samplesPerZone: configuration.samplesPerZone)
    }

    /// A distinct valid vector per index, so covariance is non-degenerate.
    private func vector(_ index: Int) -> FeatureVector {
        let offset = Double(index)
        return FeatureVector(
            peakAmplitude: 0.4 + offset * 0.01,
            rmsEnergy: 0.2 + offset * 0.005,
            spectralCentroid: 1900 + offset * 7,
            spectralBandwidth: 300 + offset * 3,
            spectralRollOff: 3500 + offset * 11,
            dominantFrequency: 2000 + offset * 5,
            zeroCrossingRate: 0.08 + offset * 0.001,
            attackTime: 1.0 + offset * 0.05,
            decayTime: 4.0 + offset * 0.07,
            signalDuration: 12.0 + offset * 0.09)
    }

    func testCoordinatorStartsIdleAndBeginsAtFirstZone() throws {
        let coordinator = try makeCoordinator()
        XCTAssertEqual(coordinator.state, .idle)
        coordinator.begin()
        XCTAssertEqual(coordinator.state, .collecting(zone: .topLeft, accepted: 0))
    }

    func testAcceptedSamplesAdvanceThroughZonesInCanonicalOrder() throws {
        let coordinator = try makeCoordinator()
        coordinator.begin()

        var sampleIndex = 0
        for zone in InteractionZone.calibratable {
            for expected in 1...configuration.samplesPerZone {
                let result = coordinator.offer(vector(sampleIndex))
                sampleIndex += 1
                XCTAssertEqual(result, .accepted(zone: zone, acceptedInZone: expected))
            }
        }
        XCTAssertEqual(coordinator.state, .readyToGenerate)
    }

    func testInvalidSampleIsRejectedAndDoesNotAdvance() throws {
        let coordinator = try makeCoordinator()
        coordinator.begin()

        let invalid = FeatureVector(
            peakAmplitude: .nan, rmsEnergy: 0.2, spectralCentroid: 1900, spectralBandwidth: 300,
            spectralRollOff: 3500, dominantFrequency: 2000, zeroCrossingRate: 0.08,
            attackTime: 1, decayTime: 4, signalDuration: 12)

        XCTAssertEqual(coordinator.offer(invalid), .rejected(.invalidFeatureVector))
        XCTAssertEqual(
            coordinator.state, .collecting(zone: .topLeft, accepted: 0),
            "a rejected sample must not advance the session")
    }

    func testSamplesBeforeBeginAreNotCollected() throws {
        let coordinator = try makeCoordinator()
        XCTAssertEqual(coordinator.offer(vector(0)), .notCollecting)
    }

    func testProfileGeneratedOnlyWhenComplete() throws {
        let coordinator = try makeCoordinator()
        coordinator.begin()

        if case .failure(let error) = coordinator.generateProfile() {
            XCTAssertEqual(error, .notReadyToGenerate)
        } else {
            XCTFail("generation must fail before all zones are collected")
        }

        var sampleIndex = 0
        for _ in InteractionZone.calibratable {
            for _ in 1...configuration.samplesPerZone {
                coordinator.offer(vector(sampleIndex))
                sampleIndex += 1
            }
        }

        switch coordinator.generateProfile(createdAt: Date(timeIntervalSince1970: 0)) {
        case .success(let profile):
            XCTAssertEqual(profile.zones.count, InteractionZone.calibratable.count)
            XCTAssertEqual(profile.deviceIdentifier, "test")
            XCTAssertEqual(coordinator.state, .completed)
        case .failure(let error):
            XCTFail("expected a profile, got \(error)")
        }
    }

    func testCaptureWithoutAudioTimesOut() throws {
        let coordinator = try makeCoordinator()
        coordinator.begin()
        XCTAssertEqual(coordinator.captureSample(timeout: 0.05), .timedOut)
        XCTAssertEqual(
            coordinator.state, .collecting(zone: .topLeft, accepted: 0),
            "a timeout must not advance the session")
    }
}
