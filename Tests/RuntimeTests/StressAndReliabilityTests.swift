import Foundation
import XCTest

@testable import Audio
@testable import Calibration
@testable import Classification
@testable import Commands
@testable import Configuration
@testable import Detection
@testable import Diagnostics
@testable import Features
@testable import Runtime
@testable import SystemIntegration

/// Stress and reliability coverage (`TEST_PLAN` §10–§12).
///
/// These exercise sustained operation and the documented failure paths in
/// process. Scenarios that need a real device — sleep/wake, physical microphone
/// reconnection, live permission changes — are hardware validation and are not
/// simulated here.
final class StressAndReliabilityTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920
    private let epoch = Date(timeIntervalSince1970: 0)

    private func tapFrame() -> [Double] {
        (0..<frameSize).map {
            0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    private func noiseFrame() -> [Double] {
        (0..<frameSize).map { 0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
    }

    private final class CountingProvider: CommandProvider, @unchecked Sendable {
        let commandType: CommandType = .shellCommand
        private(set) var count = 0
        func execute(_ command: Command) -> CommandResult {
            count += 1
            return .success(commandID: command.id, at: Date(timeIntervalSince1970: 0))
        }
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
                threshold: ThresholdModel(acceptanceThreshold: 1_000_000, ambiguityMargin: 0))
        }
        return CalibrationProfile(
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "stress", createdAt: epoch,
            zones: zones,
            normalization: NormalizationParameters(
                means: [Double](repeating: 0, count: dimension),
                standardDeviations: [Double](repeating: 1, count: dimension)),
            configuration: .v1)
    }

    // MARK: Stress (`TEST_PLAN` §10)

    func testSustainedFrameProcessingKeepsDiagnosticsBounded() throws {
        let provider = CountingProvider()
        let log = DiagnosticsLog(capacity: 100)
        let history = RecognitionLog(capacity: 100)
        var runtime = RecognitionRuntime(
            detector: try TapDetector.v1(),
            classifier: ZoneClassifier(),
            calibrationProfile: makeProfile(),
            cooldown: CooldownGate(duration: 0.1),
            bindings: PersistedCommandBindings(
                bindings: InteractionZone.calibratable.map {
                    CommandBinding(zone: $0, command: Command(type: .shellCommand, target: "noop"))
                }),
            executor: CommandExecutor(providers: [provider]),
            logger: DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug),
            recognitionLog: history)

        // Continuous tapping: alternate noise and taps well beyond the log
        // capacities so eviction is exercised.
        let noise = noiseFrame()
        let tap = tapFrame()
        for index in 0..<400 {
            let time = epoch.addingTimeInterval(Double(index) * 0.5)
            _ = runtime.process(frame: index.isMultiple(of: 2) ? noise : tap, at: time)
        }

        XCTAssertLessThanOrEqual(log.count, 100, "diagnostics must stay bounded")
        XCTAssertLessThanOrEqual(history.count, 100, "history must stay bounded")
        XCTAssertGreaterThan(provider.count, 0, "sustained operation still executes commands")
    }

    func testRapidSuccessiveTapsAreSuppressedByCooldownNotLost() throws {
        let provider = CountingProvider()
        var runtime = RecognitionRuntime(
            detector: try TapDetector.v1(),
            classifier: ZoneClassifier(),
            calibrationProfile: makeProfile(),
            cooldown: CooldownGate(duration: 0.1),
            bindings: PersistedCommandBindings(
                bindings: InteractionZone.calibratable.map {
                    CommandBinding(zone: $0, command: Command(type: .shellCommand, target: "noop"))
                }),
            executor: CommandExecutor(providers: [provider]))

        _ = runtime.process(frame: noiseFrame(), at: epoch)
        // Ten taps 10 ms apart, inside a 100 ms cooldown.
        for index in 0..<10 {
            _ = runtime.process(
                frame: tapFrame(), at: epoch.addingTimeInterval(Double(index) * 0.01))
        }
        XCTAssertEqual(provider.count, 1, "duplicate suppression holds under rapid tapping")
    }

    func testRingBufferStaysBoundedUnderSustainedWrites() {
        let ring = RollingAudioBuffer(capacity: 4_096)
        let block = [Float](repeating: 0.01, count: 256)
        for _ in 0..<10_000 { ring.write(block, hostTime: 0) }
        XCTAssertEqual(ring.availableSampleCount, 4_096, "constant memory under sustained writes")
        XCTAssertEqual(ring.totalSamplesWritten, 2_560_000)
    }

    func testRepeatedConfigurationWritesRemainConsistent() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-stress-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(store: AtomicFileStore(directory: directory))

        for index in 0..<200 {
            try store.save(
                UserPreferences(
                    diagnosticsEnabled: index.isMultiple(of: 2), loggingLevel: .info,
                    launchAtLogin: false, automaticUpdates: false))
        }
        guard case .loaded(let preferences) = store.loadPreferences() else {
            return XCTFail("repeated writes must leave a loadable file")
        }
        XCTAssertFalse(preferences.diagnosticsEnabled, "last write wins (index 199 is odd)")

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".tmp") }
        XCTAssertEqual(leftovers, [], "no partial files after repeated writes")
    }

    func testContinuousLoggingStaysBounded() {
        let log = DiagnosticsLog(capacity: 100)
        let logger = DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug)
        for index in 0..<10_000 {
            logger.record(.info, category: .runtime, "event \(index)", at: epoch)
        }
        XCTAssertEqual(log.count, 100, "continuous logging must not grow without bound")
    }

    // MARK: Error handling (`TEST_PLAN` §12)

    func testMicrophoneUnavailablePausesRecognition() {
        let capabilities = SystemCapabilities(
            microphone: .denied, accessibility: .authorized, automation: .notDetermined)
        let outcome = RuntimeStartup.evaluate(
            capabilities: capabilities, recognitionEnabled: true,
            loadProfile: { self.makeProfile() })
        XCTAssertEqual(outcome, .blocked(.microphoneUnavailable))
        XCTAssertFalse(
            RuntimeStartup.status(for: outcome, capabilities: capabilities).healthy,
            "recognition pauses rather than crashing")
    }

    func testInvalidConfigurationRestoresDefaults() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-recover-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileStore = AtomicFileStore(directory: directory)
        let store = ConfigurationStore(store: fileStore)

        try fileStore.write(Data("{ corrupt".utf8), to: ConfigurationStore.FileName.preferences)
        XCTAssertEqual(store.loadPreferences().value, .defaults)
    }

    func testCorruptCalibrationRequestsRecalibration() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-recal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileStore = AtomicFileStore(directory: directory)
        let store = ConfigurationStore(store: fileStore)
        try fileStore.write(
            Data("{ corrupt".utf8), to: ConfigurationStore.FileName.calibrationProfile)

        let outcome = RuntimeStartup.evaluate(
            capabilities: SystemCapabilities(
                microphone: .authorized, accessibility: .authorized, automation: .notDetermined),
            recognitionEnabled: true,
            loadProfile: { try store.loadCalibrationProfile() })

        guard case .blocked(.calibrationInvalid) = outcome else {
            return XCTFail("corrupt calibration must request recalibration, got \(outcome)")
        }
    }

    func testCommandFailureIsLoggedWithoutStoppingRecognition() throws {
        final class FailingProvider: CommandProvider, @unchecked Sendable {
            let commandType: CommandType = .shellCommand
            private(set) var attempts = 0
            func execute(_ command: Command) -> CommandResult {
                attempts += 1
                return .failure(
                    commandID: command.id, at: Date(timeIntervalSince1970: 0),
                    error: .executionFailed("stress"))
            }
        }
        let provider = FailingProvider()
        let log = DiagnosticsLog(capacity: 50)
        var runtime = RecognitionRuntime(
            detector: try TapDetector.v1(),
            classifier: ZoneClassifier(),
            calibrationProfile: makeProfile(),
            cooldown: CooldownGate(duration: 0),
            bindings: PersistedCommandBindings(
                bindings: InteractionZone.calibratable.map {
                    CommandBinding(zone: $0, command: Command(type: .shellCommand, target: "noop"))
                }),
            executor: CommandExecutor(providers: [provider]),
            logger: DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug))

        _ = runtime.process(frame: noiseFrame(), at: epoch)
        for index in 0..<5 {
            _ = runtime.process(frame: tapFrame(), at: epoch.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(provider.attempts, 5, "recognition continues after each command failure")
        XCTAssertTrue(
            log.records.contains { $0.level == .error },
            "command failures are logged")
    }
}
