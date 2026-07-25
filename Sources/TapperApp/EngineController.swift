import Audio
import Foundation
import Runtime
import SwiftUI
import SystemIntegration

/// Starts and stops the recognition engine on behalf of the user interface.
///
/// Lifecycle wiring only: it starts capture, starts the recognition worker, and
/// publishes status for display. Every decision it reports comes from Runtime
/// (`RuntimeStartup`) or the subsystems themselves.
@MainActor
final class EngineController: ObservableObject {

    /// Whether recognition is currently running.
    @Published private(set) var isRunning = false

    /// A short factual status line for display.
    @Published private(set) var status = "Idle."

    /// The engine's readiness, as reported by Runtime.
    @Published private(set) var engineStatus: EngineStatus?

    private let composition: AppComposition
    private var captureSource: AVAudioEngineCaptureSource?
    private var engine: RecognitionEngine?

    init(composition: AppComposition = AppComposition()) {
        self.composition = composition
    }

    /// Requests microphone access through the Audio subsystem's documented flow,
    /// then refreshes the reported status.
    ///
    /// Only the microphone is requested proactively — it gates all capture.
    /// Accessibility and Automation are never probed here; they surface per
    /// command execution.
    func requestPermissions() async {
        let granted = await MicrophoneAuthorization.requestAccess()
        refreshStatus()
        if granted != .authorized {
            status = "Microphone access is required to start recognition."
        }
    }

    /// Refreshes the published engine status without starting anything.
    func refreshStatus() {
        let capabilities = composition.capabilities()
        let outcome = composition.evaluateStartup()
        engineStatus = RuntimeStartup.status(for: outcome, capabilities: capabilities)
        if case .blocked(let blocker) = outcome, !isRunning {
            status = CompositionFailure.startupBlocked(blocker).description
        }
    }

    /// Starts capture and the recognition worker, if the documented startup
    /// sequence permits it.
    func start() {
        guard !isRunning else { return }
        let capabilities = composition.capabilities()
        let outcome = composition.evaluateStartup()
        engineStatus = RuntimeStartup.status(for: outcome, capabilities: capabilities)

        guard case .ready(let profile) = outcome else {
            if case .blocked(let blocker) = outcome {
                status = CompositionFailure.startupBlocked(blocker).description
            }
            return
        }

        do {
            let engine = try composition.makeEngine(
                profile: profile, executor: AppComposition.makeExecutor())
            let source = composition.makeCaptureSource()
            try source.start()
            engine.start()
            self.captureSource = source
            self.engine = engine
            isRunning = true
            status = "Listening."
        } catch {
            status = "Could not start: \(error)."
        }
    }

    /// Stops the recognition worker and audio capture.
    func stop() {
        guard isRunning else { return }
        engine?.stop()
        captureSource?.stop()
        engine = nil
        captureSource = nil
        isRunning = false
        status = "Stopped."
        refreshStatus()
    }
}
