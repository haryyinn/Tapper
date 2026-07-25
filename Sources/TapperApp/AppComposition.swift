import Audio
import Calibration
import Classification
import Commands
import Configuration
import Detection
import Diagnostics
import Foundation
import Runtime
import SystemIntegration

/// Why the engine could not be assembled or started.
enum CompositionFailure: Error, CustomStringConvertible {
    case startupBlocked(StartupBlocker)
    case engineUnavailable(String)

    var description: String {
        switch self {
        case .startupBlocked(.microphoneUnavailable):
            return "Microphone access is unavailable."
        case .startupBlocked(.calibrationRequired):
            return "Calibration is required before recognition can start."
        case .startupBlocked(.calibrationInvalid(let error)):
            return "The stored calibration profile could not be loaded (\(error))."
        case .startupBlocked(.recognitionDisabled):
            return "Recognition is disabled in preferences."
        case .engineUnavailable(let detail):
            return "The recognition engine could not be created: \(detail)."
        }
    }
}

/// The application's composition root.
///
/// This is **wiring only**. It constructs each subsystem from its own public
/// API and connects them in the documented order; it contains no detection,
/// classification, persistence, or execution logic of its own.
struct AppComposition {

    let configuration: ConfigurationStore
    let diagnosticsLog: DiagnosticsLog
    let recognitionLog: RecognitionLog
    let audioBuffer: RollingAudioBuffer

    init() {
        let directory =
            AtomicFileStore.defaultDirectory()
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Tapper", isDirectory: true)
        self.configuration = ConfigurationStore(store: AtomicFileStore(directory: directory))
        self.diagnosticsLog = DiagnosticsLog()
        self.recognitionLog = RecognitionLog()
        self.audioBuffer = RollingAudioBuffer()
    }

    /// The current permission snapshot, combining the Audio-owned microphone
    /// status with the system-owned permissions.
    func capabilities() -> SystemCapabilities {
        SystemCapabilities(microphone: microphoneStatus())
    }

    /// Maps the Audio subsystem's microphone status into the system vocabulary.
    func microphoneStatus() -> PermissionStatus {
        switch MicrophoneAuthorization.current {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        }
    }

    /// Evaluates the documented startup sequence.
    ///
    /// `UserPreferences` (`DATA_MODELS` §13.6) has no stored recognition toggle,
    /// so recognition is enabled whenever the other prerequisites are met;
    /// stopping is an explicit user action through the interface.
    func evaluateStartup() -> StartupOutcome {
        RuntimeStartup.evaluate(
            capabilities: capabilities(),
            recognitionEnabled: true,
            loadProfile: { try configuration.loadCalibrationProfile() }
        )
    }

    /// Builds the recognition engine for a validated profile.
    ///
    /// - Parameters:
    ///   - profile: The active calibration profile.
    ///   - executor: The command executor to dispatch through.
    /// - Returns: The assembled engine.
    /// - Throws: ``CompositionFailure`` if the engine cannot be created.
    func makeEngine(
        profile: CalibrationProfile,
        executor: CommandExecutor
    ) throws -> RecognitionEngine {
        let preferences = configuration.loadPreferences().value
        let bindings = configuration.loadCommandBindings().value
        let detector: TapDetector
        do {
            detector = try TapDetector.v1()
        } catch {
            throw CompositionFailure.engineUnavailable(String(describing: error))
        }

        let runtime = RecognitionRuntime(
            detector: detector,
            classifier: ZoneClassifier(),
            calibrationProfile: profile,
            cooldown: CooldownGate(),
            bindings: bindings,
            executor: executor,
            logger: DiagnosticsLogger(log: diagnosticsLog, preferences: preferences),
            recognitionLog: recognitionLog
        )
        return RecognitionEngine(runtime: runtime, buffer: audioBuffer)
    }

    /// The command executor with every documented Version 1 provider.
    static func makeExecutor() -> CommandExecutor {
        CommandExecutor(providers: [
            KeyboardShortcutProvider(),
            ShellCommandProvider(),
            AppleScriptProvider(),
            ShortcutsProvider(),
            ExecutableProvider(),
        ])
    }

    /// The audio capture source writing into the shared ring buffer.
    func makeCaptureSource() -> AVAudioEngineCaptureSource {
        AVAudioEngineCaptureSource(buffer: audioBuffer)
    }
}
