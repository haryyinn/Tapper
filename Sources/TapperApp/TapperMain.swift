import Calibration
import Foundation
import SwiftUI

/// The application entry point.
///
/// Calibration and validation run **inside the application**, not as shell
/// commands. macOS attributes microphone access (TCC) to the launched
/// application bundle; a binary executed from a shell is attributed to the
/// terminal instead and cannot see the app's grant. Hosting these workflows in
/// the app keeps a single, correct permission identity.
@main
struct TapperApplication: App {

    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Tapper") {
            RootView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}

/// Owns the shared composition and the workflow controllers.
@MainActor
final class AppModel: ObservableObject {

    let composition = AppComposition()
    let engine: EngineController
    let calibration: CalibrationController
    let validation: ValidationController

    init() {
        let composition = self.composition
        self.engine = EngineController(composition: composition)
        self.calibration = CalibrationController(composition: composition)
        self.validation = ValidationController(composition: composition)
    }
}

/// The application's three workflows: recognition, calibration, validation.
struct RootView: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            RecognitionView(controller: model.engine).tabItem { Text("Recognition") }
            CalibrationView(controller: model.calibration).tabItem { Text("Calibration") }
            ValidationView(controller: model.validation).tabItem { Text("Validation") }
        }
        .frame(minWidth: 460, minHeight: 380)
        .padding(12)
    }
}

/// Start/stop the recognition engine and request microphone access.
struct RecognitionView: View {

    /// Observed directly: a nested `ObservableObject` reached through another
    /// `ObservableObject` does not propagate its changes to the view.
    @ObservedObject var controller: EngineController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recognition").font(.title3).bold()
            Text(controller.status).font(.callout).foregroundStyle(.secondary)

            if let status = controller.engineStatus {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("State").foregroundStyle(.secondary)
                        Text(status.state.rawValue)
                    }
                    GridRow {
                        Text("Microphone").foregroundStyle(.secondary)
                        Text(status.microphoneAvailable ? "available" : "unavailable")
                    }
                    GridRow {
                        Text("Calibration").foregroundStyle(.secondary)
                        Text(status.profileLoaded ? "loaded" : "not loaded")
                    }
                }
                .font(.caption)
            }

            HStack {
                Button("Request Microphone Access") {
                    Task { await controller.requestPermissions() }
                }
                Button(controller.isRunning ? "Stop" : "Start") {
                    controller.isRunning ? controller.stop() : controller.start()
                }
                .keyboardShortcut(.defaultAction)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .task { controller.refreshStatus() }
    }
}

/// Guided calibration.
struct CalibrationView: View {

    /// Observed directly: a nested `ObservableObject` reached through another
    /// `ObservableObject` does not propagate its changes to the view.
    @ObservedObject var controller: CalibrationController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibration").font(.title3).bold()
            Text(
                "Tap each zone \(controller.samplesPerZone) times. "
                    + "A countdown precedes every tap; rejected taps are retried automatically."
            )
            .font(.caption).foregroundStyle(.secondary)

            promptView

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                ForEach(controller.zones, id: \.rawValue) { zone in
                    GridRow {
                        Text(zone.rawValue).foregroundStyle(.secondary)
                        Text(
                            "\(controller.accepted[zone] ?? 0)"
                                + "/\(controller.samplesPerZone)")
                    }
                }
            }
            .font(.caption)

            Text(controller.message).font(.callout)
            if controller.retries > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("retries: \(controller.retries)").font(.caption).bold()
                    ForEach(controller.rejectionBreakdown, id: \.reason) { entry in
                        Text("  \(entry.reason): \(entry.count)").font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Start Calibration") { controller.start() }
                    .disabled(controller.isRunning)
                Button("Cancel") { controller.cancel() }
                    .disabled(!controller.isRunning)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    @ViewBuilder private var promptView: some View {
        switch controller.phase {
        case .countdown(let zone, let remaining):
            Text("Tap \(zone.rawValue) in \(remaining)…").font(.title2).bold()
        case .listening(let zone):
            Text("TAP \(zone.rawValue.uppercased()) NOW").font(.title2).bold()
        case .finished(let zones):
            Text("Complete — profile saved for \(zones) zones.").font(.title3).bold()
        case .failed:
            Text("Calibration failed.").font(.title3).bold()
        case .preparing:
            Text("Preparing…").font(.title3)
        case .idle:
            Text("Ready.").font(.title3).foregroundStyle(.secondary)
        }
    }
}

/// Guided validation.
struct ValidationView: View {

    /// Observed directly: a nested `ObservableObject` reached through another
    /// `ObservableObject` does not propagate its changes to the view.
    @ObservedObject var controller: ValidationController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation").font(.title3).bold()
            Text(
                "Records labelled taps and idle periods, then exports CSV, JSON, and a report "
                    + "to ~/TapperValidation."
            )
            .font(.caption).foregroundStyle(.secondary)

            promptView

            Text(controller.message).font(.callout)
            Text("trials recorded: \(controller.completedTrials)").font(.caption)
                .foregroundStyle(.secondary)

            GroupBox("Pacing") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    GridRow {
                        Text("Preparation")
                        Slider(value: $controller.preparationSeconds, in: 0...10, step: 0.5)
                        Text(String(format: "%.1fs", controller.preparationSeconds))
                            .monospacedDigit()
                    }
                    GridRow {
                        Text("Countdown")
                        Stepper(
                            "\(controller.countdownSeconds)s", value: $controller.countdownSeconds,
                            in: 1...10)
                        Text("")
                    }
                    GridRow {
                        Text("Tap window")
                        Slider(value: $controller.tapWindowSeconds, in: 0.4...5.0, step: 0.1)
                        Text(String(format: "%.1fs", controller.tapWindowSeconds))
                            .monospacedDigit()
                    }
                    GridRow {
                        Text("Audible cue")
                        Toggle("", isOn: $controller.audibleCue).labelsHidden()
                        Text("")
                    }
                }
                .font(.caption)
                .disabled(controller.isRunning)
            }

            HStack {
                Button("Start Validation") { controller.start() }
                    .disabled(controller.isRunning)
                Button("Cancel") { controller.cancel() }
                    .disabled(!controller.isRunning)
            }

            if let report = controller.report {
                ScrollView {
                    Text(report).font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    @ViewBuilder private var promptView: some View {
        switch controller.phase {
        case .preparing(let zone, let trial, let total):
            Text("Next: \(zone.rawValue)  (\(trial)/\(total))").font(.title2).bold()
                .foregroundStyle(.secondary)
        case .countdown(let zone, let remaining):
            Text("Tap \(zone.rawValue) in \(remaining)…").font(.title2).bold()
        case .listening(let zone, let trial, let total):
            Text("TAP \(zone.rawValue.uppercased()) NOW  (\(trial)/\(total))").font(.title2).bold()
        case .idleRecording(let seconds):
            Text("Idle recording — do not tap (\(seconds)s)").font(.title3).bold()
        case .finished:
            Text("Validation complete.").font(.title3).bold()
        case .failed:
            Text("Validation failed.").font(.title3).bold()
        case .idle:
            Text("Ready.").font(.title3).foregroundStyle(.secondary)
        }
    }
}
