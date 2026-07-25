import Foundation
import XCTest

@testable import Calibration
@testable import Commands
@testable import Configuration

final class ConfigurationValidatorTests: XCTestCase {

    private func binding(_ zone: InteractionZone, _ target: String = "echo hi") -> CommandBinding {
        CommandBinding(zone: zone, command: Command(type: .shellCommand, target: target))
    }

    // MARK: Bindings

    func testValidBindingsPass() {
        let stored = PersistedCommandBindings(bindings: [binding(.topLeft), binding(.bottomRight)])
        XCTAssertNoThrow(try ConfigurationValidator.validate(stored))
    }

    func testDuplicateZoneIsRejected() {
        let stored = PersistedCommandBindings(bindings: [binding(.topLeft), binding(.topLeft)])
        XCTAssertThrowsError(try ConfigurationValidator.validate(stored)) { error in
            XCTAssertEqual(error as? ConfigurationError, .duplicateZoneBinding("topLeft"))
        }
    }

    func testUnknownZoneIsRejected() {
        let stored = PersistedCommandBindings(bindings: [binding(.unknown)])
        XCTAssertThrowsError(try ConfigurationValidator.validate(stored)) { error in
            XCTAssertEqual(error as? ConfigurationError, .unbindableZone("unknown"))
        }
    }

    func testInvalidCommandIsRejected() {
        let stored = PersistedCommandBindings(bindings: [binding(.topLeft, "")])
        XCTAssertThrowsError(try ConfigurationValidator.validate(stored)) { error in
            guard case .invalidCommand = error as? ConfigurationError else {
                return XCTFail("expected invalidCommand, got \(error)")
            }
        }
    }

    func testUnsupportedSchemaVersionRequiresMigration() {
        let stored = PersistedCommandBindings(schemaVersion: "0.9", bindings: [])
        XCTAssertThrowsError(try ConfigurationValidator.validate(stored)) { error in
            XCTAssertEqual(error as? ConfigurationError, .migrationRequired(storedVersion: "0.9"))
        }
    }

    // MARK: Calibration profile

    private func zoneProfile(_ zone: InteractionZone, dimension: Int = 2) -> ZoneProfile {
        let identity = (0..<dimension).map { row in
            (0..<dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        return ZoneProfile(
            zone: zone,
            meanVector: MeanVector(values: [Double](repeating: 0, count: dimension)),
            covarianceMatrix: CovarianceMatrix(values: identity),
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
            threshold: ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5)
        )
    }

    private func profile(zones: [ZoneProfile]) -> CalibrationProfile {
        CalibrationProfile(
            id: UUID(),
            algorithmVersion: "1.0",
            deviceIdentifier: "test-device",
            createdAt: Date(timeIntervalSince1970: 0),
            zones: zones,
            normalization: NormalizationParameters(means: [0, 0], standardDeviations: [1, 1]),
            configuration: .v1
        )
    }

    func testCompleteProfilePasses() {
        let complete = profile(zones: InteractionZone.calibratable.map { zoneProfile($0) })
        XCTAssertNoThrow(try ConfigurationValidator.validate(complete))
    }

    func testMissingZoneIsRejected() {
        let incomplete = profile(zones: [zoneProfile(.topLeft), zoneProfile(.topRight)])
        XCTAssertThrowsError(try ConfigurationValidator.validate(incomplete)) { error in
            guard case .corruptedData(let detail) = error as? ConfigurationError else {
                return XCTFail("expected corruptedData, got \(error)")
            }
            XCTAssertTrue(detail.contains("bottomLeft"), detail)
        }
    }

    func testMismatchedMatrixDimensionsAreRejected() {
        var zones = InteractionZone.calibratable.map { zoneProfile($0) }
        zones[0] = ZoneProfile(
            zone: .topLeft,
            meanVector: MeanVector(values: [0, 0, 0]),  // dimension 3
            covarianceMatrix: CovarianceMatrix(values: [[1, 0], [0, 1]]),  // dimension 2
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: [[1, 0], [0, 1]]),
            threshold: ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5)
        )
        XCTAssertThrowsError(try ConfigurationValidator.validate(profile(zones: zones))) { error in
            guard case .corruptedData(let detail) = error as? ConfigurationError else {
                return XCTFail("expected corruptedData, got \(error)")
            }
            XCTAssertTrue(detail.contains("mismatched"), detail)
        }
    }

    func testNonFiniteStatisticsAreRejected() {
        var zones = InteractionZone.calibratable.map { zoneProfile($0) }
        zones[1] = ZoneProfile(
            zone: .topRight,
            meanVector: MeanVector(values: [.nan, 0]),
            covarianceMatrix: CovarianceMatrix(values: [[1, 0], [0, 1]]),
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: [[1, 0], [0, 1]]),
            threshold: ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5)
        )
        XCTAssertThrowsError(try ConfigurationValidator.validate(profile(zones: zones))) { error in
            guard case .corruptedData(let detail) = error as? ConfigurationError else {
                return XCTFail("expected corruptedData, got \(error)")
            }
            XCTAssertTrue(detail.contains("non-finite"), detail)
        }
    }

    func testEmptyDeviceIdentifierIsRejected() {
        let anonymous = CalibrationProfile(
            id: UUID(),
            algorithmVersion: "1.0",
            deviceIdentifier: "",
            createdAt: Date(timeIntervalSince1970: 0),
            zones: InteractionZone.calibratable.map { zoneProfile($0) },
            normalization: NormalizationParameters(means: [0, 0], standardDeviations: [1, 1]),
            configuration: .v1
        )
        XCTAssertThrowsError(try ConfigurationValidator.validate(anonymous))
    }
}
