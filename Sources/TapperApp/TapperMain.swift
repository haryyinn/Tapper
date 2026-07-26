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
            RecognitionView().tabItem { Text("Recognition") }
            CalibrationView().tabItem { Text("Calibration") }
            ValidationView().tabItem { Text("Validation") }
        }
        .frame(minWidth: 460, minHeight: 380)
        .padding(12)
    }
}

/// Start/stop the recognition engine and request microphone access.
struct RecognitionView: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recognition").font(.title3).bold()
            Text(model.engine.status).font(.callout).foregroundStyle(.secondary)

            if let status = model.engine.engineStatus {
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
                    Task { await model.engine.requestPermissions() }
                }
                Button(model.engine.isRunning ? "Stop" : "Start") {
                    model.engine.isRunning ? model.engine.stop() : model.engine.start()
                }
                .keyboardShortcut(.defaultAction)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .task { model.engine.refreshStatus() }
    }
}

/// Guided calibration.
struct CalibrationView: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibration").font(.title3).bold()
            Text(
                "Tap each zone \(model.calibration.samplesPerZone) times. "
                    + "A countdown precedes every tap; rejected taps are retried automatically."
            )
            .font(.caption).foregroundStyle(.secondary)

            promptView

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                ForEach(model.calibration.zones, id: \.rawValue) { zone in
                    GridRow {
                        Text(zone.rawValue).foregroundStyle(.secondary)
                        Text(
                            "\(model.calibration.accepted[zone] ?? 0)"
                                + "/\(model.calibration.samplesPerZone)")
                    }
                }
            }
            .font(.caption)

            Text(model.calibration.message).font(.callout)
            if model.calibration.retries > 0 {
                Text("retries: \(model.calibration.retries)").font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Start Calibration") { model.calibration.start() }
                    .disabled(model.calibration.isRunning)
                Button("Cancel") { model.calibration.cancel() }
                    .disabled(!model.calibration.isRunning)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    @ViewBuilder private var promptView: some View {
        switch model.calibration.phase {
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

    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation").font(.title3).bold()
            Text(
                "Records labelled taps and idle periods, then exports CSV, JSON, and a report "
                    + "to ~/TapperValidation."
            )
            .font(.caption).foregroundStyle(.secondary)

            promptView

            Text(model.validation.message).font(.callout)
            Text("trials recorded: \(model.validation.completedTrials)").font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Start Validation") { model.validation.start() }
                    .disabled(model.validation.isRunning)
                Button("Cancel") { model.validation.cancel() }
                    .disabled(!model.validation.isRunning)
            }

            if let report = model.validation.report {
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
        switch model.validation.phase {
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
