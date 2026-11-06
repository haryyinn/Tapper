import Audio
import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import Commands
@testable import Configuration
@testable import Detection
@testable import Diagnostics
@testable import Features
@testable import Runtime

/// Records dispatched commands instead of performing any system action, so the
/// full runtime sequence can be exercised without side effects.
private final class RecordingProvider: CommandProvider, @unchecked Sendable {
    let commandType: CommandType
    let succeeds: Bool
    private(set) var executed: [Command] = []

    init(commandType: CommandType, succeeds: Bool = true) {
        self.commandType = commandType
        self.succeeds = succeeds
    }

    func execute(_ command: Command) -> CommandResult {
        executed.append(command)
        let date = Date(timeIntervalSince1970: 0)
        return succeeds
            ? .success(commandID: command.id, at: date)
            : .failure(commandID: command.id, at: date, error: .executionFailed("stub"))
    }
}

final class RecognitionRuntimeTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920
    private let timestamp = Date(timeIntervalSince1970: 1_000)

    /// A threshold large enough to accept any observation. Feature values carry
    /// raw physical units (e.g. hertz), so Mahalanobis distances against a
    /// zero-mean identity-covariance fixture are in the thousands. The runtime
    /// tests exercise sequencing, not the classifier's discrimination, which is
    /// covered by the Phase 4 classification tests.
    private let acceptAll = 1_000_000.0

    private func noiseFrame() -> [Double] {
        (0..<frameSize).map { 0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
    }

    private func tapFrame() -> [Double] {
        (0..<frameSize).map {
            0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    /// A profile whose zones are all identical, so any tap classifies as the
    /// first zone in canonical order. The point is to exercise the runtime's
    /// sequencing, not the classifier's discrimination (covered in Phase 4).
    private func makeProfile(threshold: Double, ambiguityMargin: Double = 0)
        -> CalibrationProfile
    {
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
                threshold: ThresholdModel(
                    acceptanceThreshold: threshold, ambiguityMargin: ambiguityMargin)
            )
        }
        return CalibrationProfile(
            id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "test",
            createdAt: timestamp, zones: zones,
            normalization: NormalizationParameters(
                means: [Double](repeating: 0, count: dimension),
                standardDeviations: [Double](repeating: 1, count: dimension)),
            configuration: .v1)
    }

    private func makeRuntime(
        profile: CalibrationProfile,
        bindings: PersistedCommandBindings,
        provider: RecordingProvider,
        log: DiagnosticsLog = DiagnosticsLog(),
        recognitionLog: RecognitionLog = RecognitionLog()
    ) throws -> RecognitionRuntime {
        RecognitionRuntime(
            detector: try TapDetector.v1(),
            classifier: ZoneClassifier(),
            calibrationProfile: profile,
            cooldown: CooldownGate(duration: 0.1),
            bindings: bindings,
            executor: CommandExecutor(providers: [provider]),
            logger: DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug),
            recognitionLog: recognitionLog
        )
    }

    private var shellBindings: PersistedCommandBindings {
        PersistedCommandBindings(
            bindings: InteractionZone.calibratable.map { zone in
                CommandBinding(
                    zone: zone, command: Command(type: .shellCommand, target: "echo \(zone)"))
            })
    }

    // MARK: Sequencing

    func testQuietFrameProducesNoCandidate() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider)

        XCTAssertEqual(runtime.process(frame: noiseFrame(), at: timestamp), .noCandidate)
        XCTAssertTrue(provider.executed.isEmpty, "no command may run without a candidate")
    }

    func testAcceptedRecognitionDispatchesBoundCommand() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)  // seed the noise floor
        let outcome = runtime.process(frame: tapFrame(), at: timestamp)

        guard case .executed(let classification, let result) = outcome else {
            return XCTFail("expected execution, got \(outcome)")
        }
        XCTAssertEqual(classification.status, .success)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(provider.executed.count, 1)
    }

    // MARK: Streaming (ALGORITHM §23.4.1)

    /// Writes `samples` into `buffer` in uneven chunks, polling after each, as
    /// the audio callback and recognition worker interleave in production.
    private func stream(
        _ samples: [Double], into buffer: RollingAudioBuffer, runtime: inout RecognitionRuntime
    ) -> [FrameOutcome] {
        var outcomes: [FrameOutcome] = []
        var index = 0
        var chunk = 317
        while index < samples.count {
            let end = min(samples.count, index + chunk)
            buffer.write(samples[index..<end].map(Float.init), hostTime: 0)
            outcomes += runtime.poll(buffer: buffer, at: timestamp)
            index = end
            chunk = chunk == 317 ? 1_100 : 317
        }
        return outcomes
    }

    func testStreamedTapExecutesExactlyOnce() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider)
        let buffer = RollingAudioBuffer()
        let quiet = (0..<9_600).map { 0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
        let tap = tapFrame() + [Double](repeating: 0, count: 2_880)

        let outcomes = stream(quiet + tap + quiet, into: buffer, runtime: &runtime)

        let executed = outcomes.filter {
            if case .executed = $0 { return true }
            return false
        }
        XCTAssertEqual(executed.count, 1, "outcomes: \(outcomes.filter { $0 != .noCandidate })")
        XCTAssertEqual(provider.executed.count, 1)
        XCTAssertFalse(
            outcomes.contains {
                if case .candidateRejected = $0 { return true }
                return false
            }, "a clean tap must not be rejected")
    }

    func testUnrecognizedTapExecutesNothing() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        // A threshold of 0 accepts nothing, so classification yields `unknown`.
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: 0), bindings: shellBindings, provider: provider)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        let outcome = runtime.process(frame: tapFrame(), at: timestamp)

        guard case .notRecognized = outcome else {
            return XCTFail("expected notRecognized, got \(outcome)")
        }
        XCTAssertTrue(provider.executed.isEmpty, "fail safe: uncertainty executes nothing")
    }

    func testCooldownSuppressesSecondExecutionButNotDetection() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        _ = runtime.process(frame: tapFrame(), at: timestamp)

        // Within the 100 ms cooldown: still detected and classified, but not executed.
        let second = runtime.process(frame: tapFrame(), at: timestamp.addingTimeInterval(0.05))
        guard case .suppressedByCooldown = second else {
            return XCTFail("expected cooldown suppression, got \(second)")
        }
        XCTAssertEqual(provider.executed.count, 1, "cooldown suppresses execution only")

        // After the cooldown expires, execution resumes.
        let third = runtime.process(frame: tapFrame(), at: timestamp.addingTimeInterval(0.2))
        guard case .executed = third else {
            return XCTFail("expected execution after cooldown, got \(third)")
        }
        XCTAssertEqual(provider.executed.count, 2)
    }

    func testUnboundZoneExecutesNothing() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll),
            bindings: PersistedCommandBindings(bindings: []),
            provider: provider)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        let outcome = runtime.process(frame: tapFrame(), at: timestamp)

        guard case .noBinding = outcome else {
            return XCTFail("expected noBinding, got \(outcome)")
        }
        XCTAssertTrue(provider.executed.isEmpty)
    }

    // MARK: Failure boundaries

    func testCommandFailureDoesNotInterruptSubsequentRecognition() throws {
        let provider = RecordingProvider(commandType: .shellCommand, succeeds: false)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        let first = runtime.process(frame: tapFrame(), at: timestamp)
        guard case .executed(_, let result) = first, !result.succeeded else {
            return XCTFail("expected a failed execution, got \(first)")
        }

        // Recognition continues normally after a command failure (§26.13).
        let second = runtime.process(frame: tapFrame(), at: timestamp.addingTimeInterval(0.5))
        guard case .executed = second else {
            return XCTFail("recognition must continue after command failure, got \(second)")
        }
        XCTAssertEqual(provider.executed.count, 2)
    }

    func testRuntimeOperatesWithoutDiagnostics() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        var runtime = RecognitionRuntime(
            detector: try TapDetector.v1(),
            classifier: ZoneClassifier(),
            calibrationProfile: makeProfile(threshold: acceptAll),
            cooldown: CooldownGate(duration: 0.1),
            bindings: shellBindings,
            executor: CommandExecutor(providers: [provider]),
            logger: nil,
            recognitionLog: nil
        )

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        let outcome = runtime.process(frame: tapFrame(), at: timestamp)
        guard case .executed = outcome else {
            return XCTFail("recognition must work with diagnostics absent, got \(outcome)")
        }
    }

    // MARK: Observation

    func testDiagnosticsObserveWithoutAffectingOutcome() throws {
        let provider = RecordingProvider(commandType: .shellCommand)
        let log = DiagnosticsLog(capacity: 50)
        let history = RecognitionLog(capacity: 50)
        var runtime = try makeRuntime(
            profile: makeProfile(threshold: acceptAll), bindings: shellBindings, provider: provider,
            log: log, recognitionLog: history)

        _ = runtime.process(frame: noiseFrame(), at: timestamp)
        _ = runtime.process(frame: tapFrame(), at: timestamp)

        XCTAssertEqual(history.count, 1, "classification outcomes are recorded")
        XCTAssertFalse(log.records.isEmpty, "events are recorded")
        XCTAssertEqual(provider.executed.count, 1, "observation does not change execution")
    }
}
