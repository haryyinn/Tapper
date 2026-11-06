import Foundation
import XCTest

@testable import Calibration
@testable import Commands
@testable import Configuration

final class PersistenceManifestTests: XCTestCase {

    private var directory: URL!
    private var store: ConfigurationStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-manifest-\(UUID().uuidString)", isDirectory: true)
        store = ConfigurationStore(store: AtomicFileStore(directory: directory))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeProfile() -> CalibrationProfile {
        let identity = [[1.0, 0.0], [0.0, 1.0]]
        let zones = InteractionZone.calibratable.map { zone in
            ZoneProfile(
                zone: zone,
                meanVector: MeanVector(values: [0, 0]),
                covarianceMatrix: CovarianceMatrix(values: identity),
                inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
                threshold: ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5)
            )
        }
        return CalibrationProfile(
            id: UUID(),
            algorithmVersion: CalibrationProfile.currentAlgorithmVersion,
            deviceIdentifier: "test-device",
            createdAt: Date(timeIntervalSince1970: 1_000),
            zones: zones,
            normalization: NormalizationParameters(means: [0, 0], standardDeviations: [1, 1]),
            configuration: .v1
        )
    }

    func testNoManifestBeforeCalibration() throws {
        XCTAssertNil(try store.loadManifest(), "no manifest exists until calibration is stored")
    }

    func testManifestAggregatesStoredState() throws {
        let profile = makeProfile()
        let preferences = UserPreferences(
            diagnosticsEnabled: true, loggingLevel: .warning, launchAtLogin: false,
            automaticUpdates: false)
        let bindings = PersistedCommandBindings(bindings: [
            CommandBinding(
                zone: .topLeft, command: Command(type: .keyboardShortcut, target: "command+c"))
        ])
        try store.save(profile)
        try store.save(preferences)
        try store.save(bindings)

        let manifest = try XCTUnwrap(try store.loadManifest())
        XCTAssertEqual(manifest.calibrationProfile, profile)
        XCTAssertEqual(manifest.commandBindings, bindings)
        XCTAssertEqual(manifest.userPreferences, preferences)
    }

    func testManifestUsesDefaultsForMissingPreferencesAndBindings() throws {
        let profile = makeProfile()
        try store.save(profile)

        let manifest = try XCTUnwrap(try store.loadManifest())
        XCTAssertEqual(manifest.calibrationProfile, profile)
        XCTAssertEqual(manifest.commandBindings, .defaults)
        XCTAssertEqual(manifest.userPreferences, .defaults)
    }
}
