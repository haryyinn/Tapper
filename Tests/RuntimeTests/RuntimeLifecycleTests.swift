import Foundation
import XCTest

@testable import Calibration
@testable import Configuration
@testable import Features
@testable import Runtime
@testable import SystemIntegration

final class RuntimeLifecycleTests: XCTestCase {

    private let timestamp = Date(timeIntervalSince1970: 1_000)

    private func capabilities(microphone: PermissionStatus) -> SystemCapabilities {
        SystemCapabilities(
            microphone: microphone, accessibility: .authorized, automation: .notDetermined)
    }

    private func makeProfile() -> CalibrationProfile {
        let dimension = FeatureVector.dimension
        let identity = (0..<dimension).map { row in
            (0..<dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        let zones = InteractionZone.calibratable.map { zone in
            ZoneProfile(
                zone: zone,
                meanVector: MeanVector(values: [Double](repeating: 0, count: dimension)),
                covarianceMatrix: CovarianceMatrix(values: identity),
                inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
                threshold: ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5))
        }
        return CalibrationProfile(
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "test",
            createdAt: timestamp, zones: zones,
            normalization: NormalizationParameters(
                means: [Double](repeating: 0, count: dimension),
                standardDeviations: [Double](repeating: 1, count: dimension)),
            configuration: .v1)
    }

    // MARK: Startup evaluation

    func testReadyWhenPermittedAndCalibrated() {
        let profile = makeProfile()
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities(microphone: .authorized),
            recognitionEnabled: true,
            loadProfile: { profile })
        XCTAssertEqual(outcome, .ready(profile))
    }

    func testDeniedMicrophoneBlocksGracefully() {
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities(microphone: .denied),
            recognitionEnabled: true,
            loadProfile: { self.makeProfile() })
        XCTAssertEqual(outcome, .blocked(.microphoneUnavailable))
    }

    func testMissingCalibrationRequiresCalibrationRatherThanError() {
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities(microphone: .authorized),
            recognitionEnabled: true,
            loadProfile: { nil })
        XCTAssertEqual(outcome, .blocked(.calibrationRequired))

        let status = RuntimeStartup.status(
            for: outcome, capabilities: capabilities(microphone: .authorized))
        XCTAssertEqual(status.state, .idle, "missing calibration is not an error state")
        XCTAssertFalse(status.healthy)
    }

    func testUnusableCalibrationIsAnErrorState() {
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities(microphone: .authorized),
            recognitionEnabled: true,
            loadProfile: { throw ConfigurationError.integrityCheckFailed })
        XCTAssertEqual(outcome, .blocked(.calibrationInvalid(.integrityCheckFailed)))

        let status = RuntimeStartup.status(
            for: outcome, capabilities: capabilities(microphone: .authorized))
        XCTAssertEqual(status.state, .error, "a stored but unusable profile is unrecoverable")
    }

    func testDisabledRecognitionBlocksBeforePermissionChecks() {
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities(microphone: .denied),
            recognitionEnabled: false,
            loadProfile: { nil })
        XCTAssertEqual(outcome, .blocked(.recognitionDisabled))
    }

    // MARK: Published status

    func testReadyStatusIsHealthyAndListening() {
        let outcome = StartupOutcome.ready(makeProfile())
        let status = RuntimeStartup.status(
            for: outcome, capabilities: capabilities(microphone: .authorized))
        XCTAssertEqual(status.state, .listening)
        XCTAssertTrue(status.profileLoaded)
        XCTAssertTrue(status.healthy)
    }

    func testAccessibilityDenialDoesNotBlockStartup() {
        let restricted = SystemCapabilities(
            microphone: .authorized, accessibility: .denied, automation: .notDetermined)
        let outcome = RuntimeStartup.evaluate(
            capabilities: restricted, recognitionEnabled: true, loadProfile: { self.makeProfile() })
        guard case .ready = outcome else {
            return XCTFail("Accessibility affects command types, not recognition; got \(outcome)")
        }
    }
}
