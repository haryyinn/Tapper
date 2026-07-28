import Features
import XCTest

@testable import Calibration

/// Tests the online-learning infrastructure (ADR-015).
///
/// The infrastructure exists but is never invoked automatically; these tests
/// pin the properties that make an explicit refinement flow safe to build on.
final class ProfileRefinementTests: XCTestCase {

    private let configuration = CalibrationConfiguration.v1

    private func sample(centroid: Double) -> [Double] {
        [0.20, 0.10, centroid, 500, 2000, 460, 0.15, 1.0, 5.0, 14.0]
    }

    private var identityNormalization: NormalizationParameters {
        NormalizationParameters(
            means: [Double](repeating: 0, count: FeatureVector.dimension),
            standardDeviations: [Double](repeating: 1, count: FeatureVector.dimension))
    }

    /// A profile built through the real generator, so samples and radius are
    /// genuine rather than hand-assembled.
    private func makeProfile() throws -> CalibrationProfile {
        var zones: [ZoneProfile] = []
        for (index, zone) in InteractionZone.calibratable.enumerated() {
            let samples = (0..<configuration.samplesPerZone).map {
                sample(centroid: 1000 + Double(index) * 100 + Double($0) * 0.5)
            }
            let generated = ZoneProfileGenerator.generate(
                zone: zone, normalizedSamples: samples, configuration: configuration)
            zones.append(try generated.get())
        }
        return CalibrationProfile(
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "test",
            createdAt: Date(timeIntervalSince1970: 0), zones: zones,
            normalization: identityNormalization, configuration: configuration)
    }

    /// Refinement adds the new samples to the named zone only, and leaves the
    /// profile it was derived from untouched.
    func testRefinementAddsSamplesWithoutMutatingTheOriginal() throws {
        let profile = try makeProfile()
        let originalCounts = profile.zones.map(\.samples.count)

        let additions = [
            InteractionZone.calibratable[0]: (0..<3).map {
                sample(centroid: 1000 + Double($0) * 0.5 + 0.25)
            }
        ]
        let refined = try ProfileRefinement.refine(
            profile: profile, addingNormalized: additions
        ).get()

        XCTAssertEqual(refined.zones[0].samples.count, originalCounts[0] + 3)
        XCTAssertEqual(
            Array(refined.zones.dropFirst()).map(\.samples.count),
            Array(originalCounts.dropFirst()))
        XCTAssertEqual(profile.zones.map(\.samples.count), originalCounts)
    }

    /// The result is a distinct profile, so a refinement that turns out worse
    /// can be discarded by keeping the one already on disk.
    func testRefinementProducesANewIdentity() throws {
        let profile = try makeProfile()
        let refined = try ProfileRefinement.refine(
            profile: profile,
            addingNormalized: [InteractionZone.calibratable[0]: [sample(centroid: 1000.25)]]
        ).get()

        XCTAssertNotEqual(refined.id, profile.id)
        XCTAssertEqual(refined.normalization.means, profile.normalization.means)
        XCTAssertEqual(refined.algorithmVersion, profile.algorithmVersion)
    }

    /// The neighbour radius is recomputed from the combined sample set, so the
    /// k-NN model describes the same data as the statistical model.
    ///
    /// Twenty samples 0.5 apart give a radius of 0.5 exactly (every
    /// leave-one-out distance is 0.5, so the standard deviation is 0). Adding
    /// three samples at the 0.25 midpoints puts seven samples at distance 0.25
    /// and sixteen at 0.5: mean 0.423913…, sample standard deviation
    /// 0.117622…, so mean + 2·σ = 0.659158….
    func testRefinementRecomputesTheNeighbourRadius() throws {
        let profile = try makeProfile()
        XCTAssertEqual(profile.zones[0].neighbourRadius!, 0.5, accuracy: 1e-12)

        let additions = [
            InteractionZone.calibratable[0]: (0..<3).map {
                sample(centroid: 1000 + Double($0) * 0.5 + 0.25)
            }
        ]
        let refined = try ProfileRefinement.refine(
            profile: profile, addingNormalized: additions
        ).get()

        XCTAssertEqual(refined.zones[0].neighbourRadius!, 0.659158, accuracy: 1e-5)
        XCTAssertEqual(refined.zones[1].neighbourRadius!, 0.5, accuracy: 1e-12)
    }

    /// A profile predating ADR-015 has no samples to combine with, so refining
    /// it is refused rather than silently rebuilding the model from the new
    /// samples alone.
    func testRefinementRefusesProfileWithoutStoredSamples() throws {
        let profile = try makeProfile()
        let stripped = profile.zones.map {
            ZoneProfile(
                zone: $0.zone, meanVector: $0.meanVector, covarianceMatrix: $0.covarianceMatrix,
                inverseCovarianceMatrix: $0.inverseCovarianceMatrix, threshold: $0.threshold)
        }
        let legacy = CalibrationProfile(
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "test", createdAt: Date(),
            zones: stripped, normalization: identityNormalization, configuration: configuration)

        let result = ProfileRefinement.refine(
            profile: legacy,
            addingNormalized: [InteractionZone.calibratable[0]: [sample(centroid: 1000.25)]])

        guard case .failure(let error) = result else {
            return XCTFail("expected refinement to be refused")
        }
        XCTAssertEqual(error, .profileCarriesNoSamples)
    }

    /// Refining with nothing to add is refused, so an empty refinement cannot
    /// quietly replace a profile with a regenerated copy of itself.
    func testRefinementRefusesEmptyInput() throws {
        let profile = try makeProfile()
        let result = ProfileRefinement.refine(profile: profile, addingNormalized: [:])

        guard case .failure(let error) = result else {
            return XCTFail("expected refinement to be refused")
        }
        XCTAssertEqual(error, .noAdditionalSamples)
    }
}
