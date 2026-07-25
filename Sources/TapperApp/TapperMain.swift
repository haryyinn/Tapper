import Foundation
import SwiftUI

/// The minimal control surface: start and stop the engine, and show readiness.
///
/// Presentation only — it holds no recognition, configuration, or command logic.
struct ContentView: View {

    @StateObject private var controller = EngineController()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tapper").font(.title2).bold()
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
                Button(controller.isRunning ? "Stop" : "Start") {
                    controller.isRunning ? controller.stop() : controller.start()
                }
                .keyboardShortcut(.defaultAction)

                Button("Request Microphone Access") {
                    Task { await controller.requestPermissions() }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 220)
        .task { controller.refreshStatus() }
    }
}

/// The application entry point.
///
/// Launching with `--calibrate` or `--validate` runs that guided flow in the
/// terminal instead of presenting the interface. Every mode runs from the same
/// signed bundle, so each inherits the app's permission identity.
@main
enum TapperMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--calibrate") {
            CalibrationCommand.run(arguments: arguments)
            return
        }
        if arguments.contains("--validate") {
            ValidationCommand.run(arguments: arguments)
            return
        }
        TapperApplication.main()
    }
}

/// The SwiftUI application shell.
struct TapperApplication: App {
    var body: some Scene {
        WindowGroup("Tapper") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
