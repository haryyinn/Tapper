import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import Configuration
@testable import Diagnostics

final class DiagnosticsExporterTests: XCTestCase {

    private var directory: URL!
    private var log: DiagnosticsLog!
    private var recognitionLog: RecognitionLog!
    private var exporter: DiagnosticsExporter!

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        log = DiagnosticsLog(capacity: 50)
        recognitionLog = RecognitionLog(capacity: 50)
        exporter = DiagnosticsExporter(log: log, recognitionLog: recognitionLog)
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
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "test-device",
            createdAt: now, zones: zones,
            normalization: NormalizationParameters(means: [0, 0], standardDeviations: [1, 1]),
            configuration: .v1)
    }

    private func makeBundle(profile: CalibrationProfile? = nil) -> DiagnosticsBundle {
        exporter.makeBundle(
            calibrationProfile: profile,
            preferences: .defaults,
            commandBindings: .defaults,
            appVersion: "1.0.0",
            osVersion: "macOS 14.0",
            date: now
        )
    }

    func testBundleCapturesObservedState() {
        log.record(
            DiagnosticsRecord(
                timestamp: now, level: .warning, category: .audio, message: "device changed"))
        recognitionLog.record(
            ClassificationOutcome(
                status: .success, zone: .topLeft, distance: 1, confidence: 70,
                acceptanceThreshold: 3, secondBestDistance: 4, timestamp: now))

        let bundle = makeBundle(profile: makeProfile())
        XCTAssertEqual(bundle.records.map(\.message), ["device changed"])
        XCTAssertEqual(bundle.recognitionHistory.map(\.zone), [.topLeft])
        XCTAssertEqual(bundle.appVersion, "1.0.0")
        XCTAssertEqual(bundle.osVersion, "macOS 14.0")
        XCTAssertEqual(bundle.schemaVersion, "1.0")
        XCTAssertNotNil(bundle.calibrationProfile)
    }

    func testBundleWithoutCalibrationProfileIsExportable() throws {
        let bundle = makeBundle(profile: nil)
        XCTAssertNil(bundle.calibrationProfile)
        XCTAssertNoThrow(try exporter.encode(bundle))
    }

    func testExportWritesJSONToCallerSpecifiedDestination() throws {
        let destination = directory.appendingPathComponent("tapper-diagnostics.json")
        try exporter.export(makeBundle(profile: makeProfile()), to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let contents = try String(contentsOf: destination, encoding: .utf8)
        XCTAssertTrue(contents.contains("\"appVersion\""), "human-readable JSON expected")
        XCTAssertTrue(
            contents.contains("2023-11-14"), "ISO-8601 dates expected: \(contents.prefix(200))")
    }

    func testExportLeavesNoTemporaryFiles() throws {
        let destination = directory.appendingPathComponent("bundle.json")
        try exporter.export(makeBundle(), to: destination)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [], "atomic export must leave no partial data")
    }

    /// Recursively collects every JSON key in a decoded object graph.
    private func allKeys(in object: Any) -> Set<String> {
        if let dictionary = object as? [String: Any] {
            return dictionary.reduce(into: Set(dictionary.keys)) { keys, entry in
                keys.formUnion(allKeys(in: entry.value))
            }
        }
        if let array = object as? [Any] {
            return array.reduce(into: Set<String>()) { keys, element in
                keys.formUnion(allKeys(in: element))
            }
        }
        return []
    }

    func testExportedBundleContainsNoAudioData() throws {
        log.record(
            DiagnosticsRecord(
                timestamp: now, level: .info, category: .dsp, message: "frame processed"))
        let destination = directory.appendingPathComponent("bundle.json")
        try exporter.export(makeBundle(profile: makeProfile()), to: destination)

        // Structural check: no key carries audio payloads. Substring matching
        // would false-positive on legitimate counts such as
        // `minimumRetainedSamples`, so exact key names are compared.
        let object = try JSONSerialization.jsonObject(
            with: try Data(contentsOf: destination), options: [])
        let keys = Set(allKeys(in: object).map { $0.lowercased() })
        for forbidden in ["samples", "pcm", "waveform", "audiobuffer", "audiodata", "recording"] {
            XCTAssertFalse(
                keys.contains(forbidden),
                "diagnostics must exclude audio data; found key '\(forbidden)'")
        }

        // Textual check for audio-specific terms that cannot collide with
        // legitimate configuration field names.
        let contents = try String(contentsOf: destination, encoding: .utf8).lowercased()
        for forbidden in ["pcm", "waveform", "audiobuffer", "recording"] {
            XCTAssertFalse(
                contents.contains(forbidden),
                "diagnostics must exclude audio data; found '\(forbidden)'")
        }
    }

    func testBundleRoundTripsDeterministically() throws {
        let bundle = makeBundle(profile: makeProfile())
        let first = try exporter.encode(bundle)
        XCTAssertEqual(first, try exporter.encode(bundle))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(DiagnosticsBundle.self, from: first), bundle)
    }

    func testExportToUnwritableDestinationReportsFailure() {
        let destination = URL(fileURLWithPath: "/dev/null/nested/bundle.json")
        XCTAssertThrowsError(try exporter.export(makeBundle(), to: destination)) { error in
            guard case .writeFailed = error as? DiagnosticsExportError else {
                return XCTFail("expected writeFailed, got \(error)")
            }
        }
    }
}
