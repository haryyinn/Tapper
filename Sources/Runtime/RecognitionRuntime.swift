import Calibration
import Classification
import Commands
import Configuration
import Detection
import Diagnostics
import Features
import Foundation

/// The result of offering one analysis frame to the runtime.
///
/// Reports what the orchestrator sequenced, for diagnostics and testing. It
/// carries no decision logic of its own.
public enum FrameOutcome: Sendable, Equatable {

    /// Recognition is not currently running (disabled, calibrating, or error).
    case notListening

    /// The frame contained no candidate.
    case noCandidate

    /// A candidate was detected but rejected during validation.
    case candidateRejected(RejectionReason)

    /// A candidate was classified but not accepted (unknown or ambiguous).
    case notRecognized(ClassificationOutcome)

    /// A zone was recognized but execution was suppressed by the cooldown.
    case suppressedByCooldown(ClassificationOutcome)

    /// A zone was recognized but no command is bound to it.
    case noBinding(ClassificationOutcome)

    /// A command was dispatched; the result reports whether it succeeded.
    case executed(ClassificationOutcome, CommandResult)
}

/// Sequences one recognition cycle across the subsystems
/// (`ALGORITHM` §18.16, §23.3).
///
/// The runtime is an **orchestrator**: it owns ordering and nothing else. Every
/// decision is delegated to the subsystem that owns it — detection and
/// validation to `Detection`, zone selection and acceptance to `Classification`,
/// duplicate suppression to `Detection`'s cooldown gate, binding lookup to
/// `Configuration`'s stored bindings, execution to `Commands`, and observation
/// to `Diagnostics`. No threshold, distance, or execution logic lives here.
///
/// Failure boundaries are independent: a command failure is recorded but never
/// interrupts recognition (`ALGORITHM` §26.13), and diagnostics can never
/// interrupt anything.
///
/// This type performs no audio capture and no threading of its own; the caller
/// supplies frames from the recognition worker.
public struct RecognitionRuntime {

    private var detector: TapDetector
    private let classifier: ZoneClassifier
    private let calibrationProfile: CalibrationProfile
    private var cooldown: CooldownGate
    private let bindings: PersistedCommandBindings
    private let executor: CommandExecutor
    private let logger: DiagnosticsLogger?
    private let recognitionLog: RecognitionLog?

    /// Creates a recognition runtime.
    ///
    /// - Parameters:
    ///   - detector: The tap detector (owns detection and validation).
    ///   - classifier: The zone classifier (owns acceptance and ambiguity).
    ///   - calibrationProfile: The active profile supplying the zone models and
    ///     normalization transform. Read-only here; Calibration owns it.
    ///   - cooldown: The cooldown gate (owns duplicate suppression).
    ///   - bindings: The stored zone→command bindings.
    ///   - executor: The command executor (owns execution).
    ///   - logger: Optional diagnostics logger.
    ///   - recognitionLog: Optional recognition history.
    public init(
        detector: TapDetector,
        classifier: ZoneClassifier,
        calibrationProfile: CalibrationProfile,
        cooldown: CooldownGate,
        bindings: PersistedCommandBindings,
        executor: CommandExecutor,
        logger: DiagnosticsLogger? = nil,
        recognitionLog: RecognitionLog? = nil
    ) {
        self.detector = detector
        self.classifier = classifier
        self.calibrationProfile = calibrationProfile
        self.cooldown = cooldown
        self.bindings = bindings
        self.executor = executor
        self.logger = logger
        self.recognitionLog = recognitionLog
    }

    /// Processes one analysis frame through the documented sequence.
    ///
    /// The order is fixed (`ALGORITHM` §18.16): detection → classification →
    /// cooldown → binding lookup → execution → diagnostics. Cooldown is
    /// consulted only after an accepted recognition, so it never blocks
    /// detection.
    ///
    /// - Parameters:
    ///   - frame: The analysis frame samples.
    ///   - timestamp: The frame's capture timestamp.
    /// - Returns: What the runtime sequenced for this frame.
    public mutating func process(frame: [Double], at timestamp: Date) -> FrameOutcome {
        // Stage 1-2: detection and candidate validation (owned by Detection).
        switch detector.process(frame: frame, at: timestamp) {
        case .noCandidate:
            return .noCandidate

        case .rejected(let reason):
            observe(.info, .recognition, "candidate rejected: \(reason)", at: timestamp)
            return .candidateRejected(reason)

        case .candidate(let candidate):
            return classifyAndDispatch(candidate.featureVector, at: timestamp)
        }
    }

    // MARK: Private

    private mutating func classifyAndDispatch(
        _ featureVector: FeatureVector, at timestamp: Date
    ) -> FrameOutcome {
        // Stage 3: classification (owned by Classification).
        let outcome = classifier.classify(
            featureVector: featureVector,
            profiles: calibrationProfile.zones,
            normalization: calibrationProfile.normalization,
            at: timestamp
        )
        recognitionLog?.record(outcome)

        guard outcome.status == .success else {
            observe(.info, .classification, "not recognized: \(outcome.status)", at: timestamp)
            return .notRecognized(outcome)
        }

        // Stage 4: cooldown (owned by Detection) — after acceptance, before
        // execution, so detection is never blocked.
        guard !cooldown.isActive(at: timestamp) else {
            observe(.info, .recognition, "execution suppressed by cooldown", at: timestamp)
            return .suppressedByCooldown(outcome)
        }

        // Stage 5: binding lookup (owned by Configuration).
        guard let binding = bindings.binding(for: outcome.zone) else {
            observe(
                .info, .command, "no command bound to zone \(outcome.zone.rawValue)", at: timestamp)
            return .noBinding(outcome)
        }

        // Stage 6: execution (owned by Commands). A command failure is recorded
        // but never interrupts recognition (§26.13).
        let result = executor.execute(binding.command, at: timestamp)
        cooldown.recordRecognition(at: timestamp)

        observe(
            result.succeeded ? .info : .error,
            .command,
            result.succeeded
                ? "executed command for zone \(outcome.zone.rawValue)"
                : "command failed for zone \(outcome.zone.rawValue): "
                    + (result.errorMessage ?? "unknown error"),
            at: timestamp
        )
        return .executed(outcome, result)
    }

    /// Records a diagnostic event. Diagnostics is best effort and can never
    /// affect the outcome of this cycle.
    private func observe(
        _ level: LogLevel, _ category: DiagnosticsCategory, _ message: String, at date: Date
    ) {
        logger?.record(level, category: category, message, at: date)
    }
}
