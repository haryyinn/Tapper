import Foundation
import XCTest

@testable import Calibration
@testable import Commands
@testable import Configuration

final class ConfigurationStoreTests: XCTestCase {

    private var directory: URL!
    private var fileStore: AtomicFileStore!
    private var store: ConfigurationStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-config-\(UUID().uuidString)", isDirectory: true)
        fileStore = AtomicFileStore(directory: directory)
        store = ConfigurationStore(store: fileStore)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeRaw(_ contents: String, to fileName: String) throws {
        try fileStore.write(Data(contents.utf8), to: fileName)
    }

    // MARK: Preferences

    func testPreferencesRoundTrip() throws {
        let preferences = UserPreferences(
            diagnosticsEnabled: true, loggingLevel: .debug, launchAtLogin: true,
            automaticUpdates: false)
        try store.save(preferences)
        XCTAssertEqual(store.loadPreferences(), .loaded(preferences))
    }

    func testMissingPreferencesUseDefaults() {
        XCTAssertEqual(store.loadPreferences(), .defaultsUsedNoStoredData(.defaults))
    }

    func testCorruptPreferencesRestoreDefaultsWithReason() throws {
        try writeRaw("{ not valid json", to: ConfigurationStore.FileName.preferences)
        let load = store.loadPreferences()
        XCTAssertEqual(load.value, .defaults)
        guard case .defaultsRestoredAfterFailure(_, let error) = load,
            case .corruptedData = error
        else {
            return XCTFail("expected corruptedData recovery, got \(load)")
        }
    }

    func testUnsupportedPreferencesVersionReportsMigrationRequired() throws {
        try writeRaw(
            """
            {"schemaVersion":"0.9","preferences":{"diagnosticsEnabled":false,\
            "loggingLevel":"info","launchAtLogin":false,"automaticUpdates":false}}
            """,
            to: ConfigurationStore.FileName.preferences)
        let load = store.loadPreferences()
        guard case .defaultsRestoredAfterFailure(_, .migrationRequired(let version)) = load else {
            return XCTFail("expected migrationRequired, got \(load)")
        }
        XCTAssertEqual(version, "0.9")
    }

    // MARK: Bindings

    func testBindingsRoundTrip() throws {
        let bindings = PersistedCommandBindings(bindings: [
            CommandBinding(zone: .topLeft, command: Command(type: .shellCommand, target: "echo a"))
        ])
        try store.save(bindings, userConfirmed: true)
        XCTAssertEqual(store.loadCommandBindings(), .loaded(bindings))
    }

    func testInvalidBindingsAreNeverWritten() {
        let duplicated = PersistedCommandBindings(bindings: [
            CommandBinding(zone: .topLeft, command: Command(type: .shellCommand, target: "a")),
            CommandBinding(zone: .topLeft, command: Command(type: .shellCommand, target: "b")),
        ])
        XCTAssertThrowsError(try store.save(duplicated))
        XCTAssertFalse(fileStore.fileExists(ConfigurationStore.FileName.commandBindings))
    }

    func testCorruptBindingsRestoreDefaults() throws {
        try writeRaw("garbage", to: ConfigurationStore.FileName.commandBindings)
        let load = store.loadCommandBindings()
        XCTAssertEqual(load.value, .defaults)
        guard case .defaultsRestoredAfterFailure = load else {
            return XCTFail("expected defaults restoration, got \(load)")
        }
    }

    // MARK: Calibration profile

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

    func testCalibrationProfileRoundTrip() throws {
        let profile = makeProfile()
        try store.save(profile)
        XCTAssertEqual(try store.loadCalibrationProfile(), profile)
    }

    func testProfileFromOtherAlgorithmVersionIsRefused() throws {
        // ADR-017 §7: a profile built under other feature definitions is
        // refused, never reinterpreted.
        let current = makeProfile()
        let stale = CalibrationProfile(
            id: current.id, algorithmVersion: "1.0", deviceIdentifier: current.deviceIdentifier,
            createdAt: current.createdAt, zones: current.zones,
            normalization: current.normalization, configuration: current.configuration)
        try store.save(stale)
        XCTAssertThrowsError(try store.loadCalibrationProfile()) { error in
            XCTAssertEqual(
                error as? ConfigurationError,
                .recalibrationRequired(profileAlgorithmVersion: "1.0"))
        }
    }

    func testMissingCalibrationProfileReturnsNil() throws {
        XCTAssertNil(try store.loadCalibrationProfile())
    }

    func testTamperedCalibrationProfileFailsIntegrityCheck() throws {
        try store.save(makeProfile())
        let url = fileStore.url(for: ConfigurationStore.FileName.calibrationProfile)
        let original = try String(contentsOf: url, encoding: .utf8)
        // Alter a value inside the profile without touching the stored checksum,
        // so the recomputed digest must differ.
        XCTAssertTrue(original.contains("test-device"), "precondition for the tamper")
        let tampered = original.replacingOccurrences(of: "test-device", with: "other-device")
        try fileStore.write(
            Data(tampered.utf8), to: ConfigurationStore.FileName.calibrationProfile)

        XCTAssertThrowsError(try store.loadCalibrationProfile()) { error in
            XCTAssertEqual(error as? ConfigurationError, .integrityCheckFailed)
        }
    }

    func testCorruptCalibrationProfileThrowsRatherThanUsingDefaults() throws {
        try writeRaw("{ broken", to: ConfigurationStore.FileName.calibrationProfile)
        XCTAssertThrowsError(try store.loadCalibrationProfile()) { error in
            guard case .corruptedData = error as? ConfigurationError else {
                return XCTFail("expected corruptedData, got \(error)")
            }
        }
    }

    func testChecksumIsDeterministicAndSensitive() {
        let a = ConfigurationStore.checksum(of: Data("payload".utf8))
        XCTAssertEqual(a, ConfigurationStore.checksum(of: Data("payload".utf8)))
        XCTAssertNotEqual(a, ConfigurationStore.checksum(of: Data("payloae".utf8)))
        XCTAssertEqual(a.count, 64, "SHA-256 hex digest")
    }

    // MARK: Restore defaults

    func testRestoreDefaultsResetsPreferencesAndBindingsOnly() throws {
        let profile = makeProfile()
        try store.save(profile)
        try store.save(
            UserPreferences(
                diagnosticsEnabled: true, loggingLevel: .debug, launchAtLogin: true,
                automaticUpdates: true))
        try store.save(
            PersistedCommandBindings(bindings: [
                CommandBinding(
                    zone: .topLeft, command: Command(type: .shellCommand, target: "echo a"))
            ]), userConfirmed: true)

        try store.restoreDefaults()

        XCTAssertEqual(store.loadPreferences().value, .defaults)
        XCTAssertEqual(store.loadCommandBindings().value, .defaults)
        XCTAssertEqual(
            try store.loadCalibrationProfile(), profile,
            "restoring defaults must not invalidate calibration")
    }
}
