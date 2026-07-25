import Audio
import Calibration
import Commands
import Configuration
import Foundation
import Runtime
import SystemIntegration

/// The guided validation harness (`--validate`).
///
/// Prompts the operator for each tap, labels the expected zone automatically,
/// records what the engine reported, and writes CSV, JSON, and a summary
/// report. Its purpose is to remove manual counting from hardware validation.
///
/// It measures; it never tunes. No detection constant is modified here.
enum ValidationCommand {

    private static let appVersion = "0.1.0-validation"

    static func run(arguments: [String]) {
        let repetitions = intValue(named: "--reps", in: arguments) ?? 25
        let idleSeconds = intValue(named: "--idle", in: arguments) ?? 60
        let outputDirectory =
            stringValue(named: "--out", in: arguments).map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("TapperValidation", isDirectory: true)

        print("Tapper guided validation")
        print(String(repeating: "=", count: 72))

        let composition = AppComposition()

        guard composition.capabilities().allowsRecognition else {
            print("Microphone access is not granted. Grant it and run again.")
            print("Status: \(composition.capabilities().microphone.rawValue)")
            return
        }

        let profile: CalibrationProfile
        switch composition.evaluateStartup() {
        case .ready(let loaded):
            profile = loaded
        case .blocked(let blocker):
            print("Cannot start: \(CompositionFailure.startupBlocked(blocker).description)")
            print("Calibrate first, then run validation again.")
            return
        }

        // Commands are not executed during validation: the run measures
        // recognition, and firing real commands would have side effects.
        let executor = CommandExecutor(providers: [])
        let engine: RecognitionEngine
        let source: AVAudioEngineCaptureSource
        do {
            engine = try composition.makeEngine(profile: profile, executor: executor)
            source = composition.makeCaptureSource()
            try source.start()
        } catch {
            print("Could not start the engine: \(error)")
            return
        }
        engine.start()
        defer {
            engine.stop()
            source.stop()
        }

        let recorder = TrialRecorder()
        engine.setFrameObserver { outcome, timestamp in
            recorder.observe(outcome: outcome, at: timestamp)
        }

        let startedAt = Date()
        var trials: [ValidationTrial] = []
        var index = 0

        print("\nEach prompt asks for one deliberate tap. Press Return when ready,")
        print("then tap the named zone once. Press Ctrl-C to abort.\n")

        for zone in InteractionZone.calibratable {
            print("--- \(zone.rawValue): \(repetitions) taps ---")
            for repetition in 1...repetitions {
                print(
                    "  [\(repetition)/\(repetitions)] tap \(zone.rawValue), then press Return...",
                    terminator: "")
                _ = readLine()
                recorder.reset()
                Thread.sleep(forTimeInterval: 0.6)
                index += 1
                trials.append(recorder.makeTrial(index: index, expectedZone: zone))
                print("      -> \(trials[trials.count - 1].outcome)")
            }
        }

        print("\n--- idle recording: \(idleSeconds)s ---")
        print("Do NOT tap. Type, speak, move the laptop — anything except a deliberate tap.")
        print("Press Return to begin...", terminator: "")
        _ = readLine()

        // Each idle second is one opportunity for a false positive.
        for second in 1...max(1, idleSeconds) {
            recorder.reset()
            Thread.sleep(forTimeInterval: 1.0)
            index += 1
            trials.append(recorder.makeTrial(index: index, expectedZone: nil))
            if second % 10 == 0 { print("  \(second)/\(idleSeconds)s") }
        }

        let run = ValidationRun(
            startedAt: startedAt,
            completedAt: Date(),
            appVersion: appVersion,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            trials: trials
        )
        let summary = ValidationSummary.make(from: run.trials)
        let report = ValidationExport.report(run, summary: summary)

        print("\n" + report)
        write(run: run, report: report, to: outputDirectory)
    }

    private static func write(run: ValidationRun, report: String, to directory: URL) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: run.completedAt)
                .replacingOccurrences(of: ":", with: "-")
            let store = AtomicFileStore(directory: directory)
            try store.write(Data(ValidationExport.csv(run).utf8), to: "validation-\(stamp).csv")
            try store.write(try ValidationExport.json(run), to: "validation-\(stamp).json")
            try store.write(Data(report.utf8), to: "validation-\(stamp).txt")
            print("Written to \(directory.path)")
        } catch {
            print("Could not write results: \(error)")
        }
    }

    private static func stringValue(named name: String, in arguments: [String]) -> String? {
        guard let position = arguments.firstIndex(of: name), position + 1 < arguments.count else {
            return nil
        }
        return arguments[position + 1]
    }

    private static func intValue(named name: String, in arguments: [String]) -> Int? {
        stringValue(named: name, in: arguments).flatMap(Int.init)
    }
}

/// Collects the frames observed during a single trial window.
private final class TrialRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var observations: [(outcome: FrameOutcome, timestamp: Date, latency: Double)] = []
    private var windowStart = Date()

    func reset() {
        lock.lock()
        observations.removeAll()
        windowStart = Date()
        lock.unlock()
    }

    func observe(outcome: FrameOutcome, at timestamp: Date) {
        lock.lock()
        let latency = timestamp.timeIntervalSince(windowStart) * 1000
        observations.append((outcome, timestamp, latency))
        lock.unlock()
    }

    /// Builds a trial from the observations in the window.
    ///
    /// The most decisive outcome wins: an execution or recognized zone outranks
    /// a rejection, which outranks "no candidate".
    func makeTrial(index: Int, expectedZone: InteractionZone?) -> ValidationTrial {
        lock.lock()
        let observed = observations
        lock.unlock()

        var detectedZone: String?
        var status: String?
        var confidence: Double?
        var distance: Double?
        var outcomeLabel = "noCandidate"
        var latency = 0.0

        for entry in observed {
            switch entry.outcome {
            case .noCandidate, .notListening:
                continue
            case .candidateRejected(let reason):
                if outcomeLabel == "noCandidate" {
                    outcomeLabel = "rejected(\(reason))"
                    latency = entry.latency
                }
            case .notRecognized(let classification):
                outcomeLabel = "notRecognized(\(classification.status))"
                status = String(describing: classification.status)
                confidence = classification.confidence
                distance = classification.distance
                latency = entry.latency
            case .suppressedByCooldown(let classification),
                .noBinding(let classification):
                detectedZone = classification.zone.rawValue
                status = String(describing: classification.status)
                confidence = classification.confidence
                distance = classification.distance
                outcomeLabel = "recognized(\(classification.zone.rawValue))"
                latency = entry.latency
            case .executed(let classification, _):
                detectedZone = classification.zone.rawValue
                status = String(describing: classification.status)
                confidence = classification.confidence
                distance = classification.distance
                outcomeLabel = "executed(\(classification.zone.rawValue))"
                latency = entry.latency
            }
        }

        let succeeded: Bool
        if let expectedZone {
            succeeded = detectedZone == expectedZone.rawValue
        } else {
            // An idle trial succeeds when nothing was recognized.
            succeeded = detectedZone == nil
        }

        return ValidationTrial(
            index: index,
            expectedZone: expectedZone?.rawValue,
            detectedZone: detectedZone,
            status: status,
            confidence: confidence,
            distance: distance,
            latencyMilliseconds: latency,
            outcome: outcomeLabel,
            succeeded: succeeded,
            timestamp: Date()
        )
    }
}
