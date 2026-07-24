import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import Features

/// End-to-end Phase 4 test: calibrate four synthetic zone clusters through the
/// headless session, then classify taps with the resulting profile.
final class CalibrateAndClassifyTests: XCTestCase {

    private let timestamp = Date(timeIntervalSince1970: 0)

    // Zone centers vary in spectral centroid and dominant frequency.
    private let centers: [(zone: InteractionZone, centroid: Double, dominant: Double)] = [
        (.topLeft, 1000, 800), (.topRight, 2000, 1600),
        (.bottomLeft, 3000, 2400), (.bottomRight, 4000, 3200),
    ]

    /// A valid feature vector from a zone center with small deterministic jitter.
    private func vector(centroid: Double, dominant: Double, k: Int) -> FeatureVector {
        FeatureVector(
            peakAmplitude: 0.5, rmsEnergy: 0.3 + 0.001 * Double(k % 5),
            spectralCentroid: centroid + 15 * sin(Double(k)), spectralBandwidth: 800,
            spectralRollOff: 4000, dominantFrequency: dominant + 10 * cos(Double(k)),
            zeroCrossingRate: 0.1, attackTime: 2, decayTime: 5, signalDuration: 10)
    }

    private func calibratedProfile() throws -> CalibrationProfile {
        var session = CalibrationSession(
            configuration: .v1, deviceIdentifier: "device", algorithmVersion: "1.0")
        session.begin()
        for center in centers {
            for k in 0..<CalibrationConfiguration.v1.samplesPerZone {
                _ = session.addSample(
                    vector(centroid: center.centroid, dominant: center.dominant, k: k))
            }
        }
        return try session.generateProfile(createdAt: timestamp).get()
    }

    func testInClusterTapsClassifyToTheirZones() throws {
        let profile = try calibratedProfile()
        let classifier = ZoneClassifier()
        for center in centers {
            let tap = vector(centroid: center.centroid, dominant: center.dominant, k: 3)
            let outcome = classifier.classify(
                featureVector: tap, profiles: profile.zones,
                normalization: profile.normalization, at: timestamp)
            XCTAssertEqual(outcome.status, .success, "zone \(center.zone)")
            XCTAssertEqual(outcome.zone, center.zone)
        }
    }

    func testFarTapIsUnknown() throws {
        let profile = try calibratedProfile()
        let farTap = FeatureVector(
            peakAmplitude: 0.5, rmsEnergy: 0.3, spectralCentroid: 8000, spectralBandwidth: 800,
            spectralRollOff: 4000, dominantFrequency: 6000, zeroCrossingRate: 0.1, attackTime: 2,
            decayTime: 5, signalDuration: 10)
        let outcome = ZoneClassifier().classify(
            featureVector: farTap, profiles: profile.zones,
            normalization: profile.normalization, at: timestamp)
        XCTAssertEqual(outcome.status, .unknown)
        XCTAssertEqual(outcome.zone, .unknown)
    }

    func testCalibrationIsDeterministic() throws {
        XCTAssertEqual(try calibratedProfile().zones, try calibratedProfile().zones)
    }
}
