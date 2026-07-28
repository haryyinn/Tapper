import AppKit
import Audio
import Calibration
import Classification
import Commands
import Configuration
import Dispatch
import Foundation
import Runtime

/// Drives a guided validation run for the user interface.
///
/// Orchestration only: it starts capture and the recognition engine, prompts for
/// each labelled tap, records what the engine reported, and exports the results
/// using the existing ``ValidationExport``. It measures and never tunes; no
/// detection constant is read or written here.
@MainActor
final class ValidationController: ObservableObject {

    enum Phase: Equatable {
        case idle
        case preparing(zone: InteractionZone, trial: Int, of: Int)
        case countdown(zone: InteractionZone, remaining: Int)
        case listening(zone: InteractionZone, trial: Int, of: Int)
        case idleRecording(secondsRemaining: Int)
        case finished(path: String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var message = "Not started."
    @Published private(set) var isRunning = false
    @Published private(set) var completedTrials = 0
    @Published private(set) var report: String?

    /// Taps collected per zone.
    @Published var repetitions = 25

    /// Seconds of idle recording, each counted as one false-positive opportunity.
    @Published var idleSeconds = 60

    /// Pause after the target zone is shown, before the countdown begins, giving
    /// the operator time to move into position.
    @Published var preparationSeconds = 2.0

    /// Length of the spoken-style countdown before each tap.
    @Published var countdownSeconds = 3

    /// How long the recorder listens for the tap after "TAP NOW".
    @Published var tapWindowSeconds = 1.2

    /// Play a short cue when the tap window opens.
    @Published var audibleCue = true

    private let composition: AppComposition
    private let queue = DispatchQueue(label: "com.tapper.validation-ui", qos: .userInitiated)
    private var captureSource: AVAudioEngineCaptureSource?
    private var engine: RecognitionEngine?
    private let cancellation = CancellationFlag()

    init(composition: AppComposition) {
        self.composition = composition
    }

    /// Starts a validation run, if a calibration profile is available.
    func start() {
        AppLog.validation("Button pressed")
        guard !isRunning else {
            AppLog.validation("Ignored: already running")
            return
        }
        guard composition.capabilities().allowsRecognition else {
            message = "Microphone access is required. Use Request Microphone Access first."
            return
        }

        let profile: CalibrationProfile
        switch composition.evaluateStartup() {
        case .ready(let loaded):
            profile = loaded
        case .blocked(let blocker):
            AppLog.validation("STOPPED: \(blocker)")
            message = CompositionFailure.startupBlocked(blocker).description
            return
        }
        AppLog.validation("Calibration profile loaded")

        // Commands are not executed during validation: the run measures
        // recognition, and firing real commands would have side effects.
        let engine: RecognitionEngine
        let source = composition.makeCaptureSource()
        do {
            engine = try composition.makeEngine(
                profile: profile, executor: CommandExecutor(providers: []))
            try source.start()
        } catch {
            message = "Could not start validation: \(error)"
            return
        }
        engine.start()
        AppLog.validation("Audio capture and recognition engine started")

        let recorder = TrialRecorder()
        engine.setFrameObserver { outcome, timestamp in
            recorder.observe(outcome: outcome, at: timestamp)
        }

        // Every benchmark recogniser classifies the same feature vector: the
        // candidate observer fires with exactly the vector production is about
        // to classify, so a difference between them is attributable to the
        // recogniser alone (ALGORITHM §17.25.3). Measurement only — these
        // verdicts are recorded and never acted on, and the engine's behaviour
        // is unchanged.
        //
        // The benchmark is built once, here, so per-tap latency measures
        // classification rather than model preparation (§17.25.4).
        let benchmark = RecogniserBenchmark.standard(
            profiles: profile.zones, normalization: profile.normalization,
            configuration: profile.configuration)
        let normalization = profile.normalization
        engine.setCandidateObserver { featureVector, timestamp in
            recorder.observe(
                measurements: benchmark.evaluate(featureVector, at: timestamp),
                normalizedVector: normalization.normalize(featureVector.values))
        }
        AppLog.validation("Benchmark recognisers: \(benchmark.identifiers.joined(separator: ", "))")
        if !profile.zones.contains(where: \.supportsNearestNeighbour) {
            AppLog.validation(
                "Sample-based recognisers unavailable: profile predates ADR-015 "
                    + "(no labelled samples). Mahalanobis results are unaffected.")
        }

        self.engine = engine
        self.captureSource = source
        cancellation.reset()
        isRunning = true
        completedTrials = 0
        report = nil
        message = "Starting..."

        let timing = Timing(
            repetitions: repetitions, idleSeconds: idleSeconds,
            preparationSeconds: preparationSeconds, countdownSeconds: countdownSeconds,
            tapWindowSeconds: tapWindowSeconds, audibleCue: audibleCue)
        let flag = cancellation
        queue.async { [weak self] in
            self?.run(recorder: recorder, timing: timing, cancellation: flag)
        }
    }

    /// Stops the run without exporting.
    func cancel() {
        cancellation.cancel()
        teardown()
        isRunning = false
        phase = .idle
        message = "Validation cancelled. Nothing was exported."
    }

    // MARK: Run loop (background queue)

    /// Immutable per-run pacing, captured when the run starts.
    struct Timing: Sendable {
        let repetitions: Int
        let idleSeconds: Int
        let preparationSeconds: Double
        let countdownSeconds: Int
        let tapWindowSeconds: Double
        let audibleCue: Bool
    }

    private nonisolated func run(
        recorder: TrialRecorder, timing: Timing, cancellation: CancellationFlag
    ) {
        var trials: [ValidationTrial] = []
        var index = 0
        let startedAt = Date()

        for zone in InteractionZone.calibratable {
            for repetition in 1...max(1, timing.repetitions) {
                if cancellation.isCancelled { return }

                // Preparation: show the target and let the operator get in place
                // before any countdown starts.
                let promptAt = Date()
                publish(
                    .preparing(zone: zone, trial: repetition, of: timing.repetitions),
                    "Move to \(zone.rawValue).")
                Thread.sleep(forTimeInterval: max(0, timing.preparationSeconds))
                if cancellation.isCancelled { return }

                let countdownAt = Date()
                for remaining in stride(from: max(1, timing.countdownSeconds), through: 1, by: -1) {
                    publish(.countdown(zone: zone, remaining: remaining), "Get ready…")
                    Thread.sleep(forTimeInterval: 1.0)
                }
                publish(
                    .listening(zone: zone, trial: repetition, of: timing.repetitions),
                    "Tap \(zone.rawValue) now.")
                if timing.audibleCue { playCue() }
                recorder.reset()
                let windowOpenedAt = Date()
                Thread.sleep(forTimeInterval: max(0.1, timing.tapWindowSeconds))
                let windowClosedAt = Date()
                index += 1
                let trial = recorder.makeTrial(
                    index: index, expectedZone: zone, promptDisplayedAt: promptAt,
                    countdownStartedAt: countdownAt, tapWindowOpenedAt: windowOpenedAt,
                    tapWindowClosedAt: windowClosedAt)
                trials.append(trial)
                note(trial.outcome, completed: index)
            }
        }

        for second in stride(from: max(1, timing.idleSeconds), through: 1, by: -1) {
            if cancellation.isCancelled { return }
            publish(.idleRecording(secondsRemaining: second), "Do not tap. Type, speak, move.")
            recorder.reset()
            let idleOpenedAt = Date()
            Thread.sleep(forTimeInterval: 1.0)
            index += 1
            trials.append(
                recorder.makeTrial(
                    index: index, expectedZone: nil, tapWindowOpenedAt: idleOpenedAt,
                    tapWindowClosedAt: Date()))
        }

        export(
            ValidationRun(
                startedAt: startedAt, completedAt: Date(), appVersion: validationAppVersion,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString, trials: trials))
    }

    private nonisolated func export(_ run: ValidationRun) {
        let summary = ValidationSummary.make(from: run.trials)
        let text = ValidationExport.report(run, summary: summary)
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("TapperValidation", isDirectory: true)

        var resultPath = directory.path
        var failure: String?
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: run.completedAt)
                .replacingOccurrences(of: ":", with: "-")
            let store = AtomicFileStore(directory: directory)
            try store.write(Data(ValidationExport.csv(run).utf8), to: "validation-\(stamp).csv")
            try store.write(try ValidationExport.json(run), to: "validation-\(stamp).json")
            try store.write(Data(text.utf8), to: "validation-\(stamp).txt")
            resultPath = directory.appendingPathComponent("validation-\(stamp).*").path
        } catch {
            failure = String(describing: error)
        }

        Task { @MainActor in
            self.report = text
            if let failure {
                self.phase = .failed("export failed")
                self.message = "Validation finished but export failed: \(failure)"
            } else {
                self.phase = .finished(path: resultPath)
                self.message = "Validation complete. Results written to \(resultPath)"
            }
            self.teardown()
            self.isRunning = false
        }
    }

    /// A short, distinct cue marking the moment the tap window opens.
    private nonisolated func playCue() {
        Task { @MainActor in
            if let sound = NSSound(named: "Tink") {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }

    private nonisolated func publish(_ phase: Phase, _ message: String) {
        Task { @MainActor in
            self.phase = phase
            self.message = message
        }
    }

    private nonisolated func note(_ outcome: String, completed: Int) {
        Task { @MainActor in
            self.completedTrials = completed
            self.message = "Recorded: \(outcome)"
        }
    }

    private func teardown() {
        engine?.stop()
        captureSource?.stop()
        engine = nil
        captureSource = nil
    }

}

/// The app version recorded in exported validation runs.
private let validationAppVersion = "0.1.0-validation"

/// Collects the frames observed during one trial window.
///
/// The most decisive outcome wins: a recognized zone outranks a rejection, which
/// outranks "no candidate".
final class TrialRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var observations: [(outcome: FrameOutcome, latency: Double)] = []
    private var windowStart = Date()
    private var firstActivity: Date?

    /// Benchmark measurements for candidates seen in the current window, with
    /// the normalized vector that produced them.
    private var measurements: [(measurements: [RecogniserMeasurement], vector: [Double])] = []

    /// When audio activity was first observed since the last ``reset()``.
    var firstDetectedAudioAt: Date? {
        lock.lock()
        defer { lock.unlock() }
        return firstActivity
    }

    func reset() {
        lock.lock()
        observations.removeAll()
        measurements.removeAll()
        windowStart = Date()
        firstActivity = nil
        lock.unlock()
    }

    /// Records the benchmark measurements for a candidate in this window.
    func observe(measurements new: [RecogniserMeasurement], normalizedVector: [Double]) {
        lock.lock()
        measurements.append((new, normalizedVector))
        lock.unlock()
    }

    func observe(outcome: FrameOutcome, at timestamp: Date) {
        lock.lock()
        observations.append((outcome, timestamp.timeIntervalSince(windowStart) * 1000))
        // Anything other than silence counts as audio activity, including a
        // detected-then-rejected tap.
        if firstActivity == nil, outcome != .noCandidate, outcome != .notListening {
            firstActivity = timestamp
        }
        lock.unlock()
    }

    func makeTrial(
        index: Int, expectedZone: InteractionZone?, promptDisplayedAt: Date? = nil,
        countdownStartedAt: Date? = nil, tapWindowOpenedAt: Date? = nil,
        tapWindowClosedAt: Date? = nil
    ) -> ValidationTrial {
        lock.lock()
        let observed = observations
        // The last measurement corresponds to the last frame that reached
        // classification, which is the frame the loop below reports. Both
        // therefore describe the same tap.
        let measured = measurements.last
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
            case .suppressedByCooldown(let classification), .noBinding(let classification):
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

        let succeeded =
            expectedZone.map { detectedZone == $0.rawValue } ?? (detectedZone == nil)

        // One record per recogniser that was evaluated. A recogniser the
        // profile could not support is absent rather than present with a failed
        // verdict, so "not evaluated" stays distinguishable from "evaluated and
        // rejected" (DATA_MODELS §7.13a).
        let verdicts = (measured?.measurements ?? []).map { measurement in
            RecogniserVerdictRecord(
                recogniser: measurement.identifier,
                zone: measurement.verdict.accepted
                    ? measurement.verdict.outcome.zone.rawValue : nil,
                status: String(describing: measurement.verdict.outcome.status),
                confidence: measurement.verdict.outcome.confidence,
                distance: measurement.verdict.distance,
                acceptanceRadius: measurement.verdict.acceptanceRadius,
                acceptanceMargin: measurement.verdict.acceptanceMargin,
                accepted: measurement.verdict.accepted,
                latencyMicroseconds: measurement.latencyMicroseconds,
                neighbours: measurement.verdict.neighbours.map {
                    String(format: "%@@%.4f", $0.zone.rawValue, $0.distance)
                })
        }

        return ValidationTrial(
            index: index, expectedZone: expectedZone?.rawValue, detectedZone: detectedZone,
            status: status, confidence: confidence, distance: distance,
            latencyMilliseconds: latency, outcome: outcomeLabel, succeeded: succeeded,
            timestamp: Date(), promptDisplayedAt: promptDisplayedAt,
            countdownStartedAt: countdownStartedAt, tapWindowOpenedAt: tapWindowOpenedAt,
            firstDetectedAudioAt: firstActivity, tapWindowClosedAt: tapWindowClosedAt,
            featureVector: measured?.vector, verdicts: verdicts)
    }
}
