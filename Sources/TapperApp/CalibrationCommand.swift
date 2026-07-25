import Audio
import Calibration
import Configuration
import Detection
import Diagnostics
import Foundation
import Runtime

/// The guided calibration interface (`--calibrate`).
///
/// Presentation only: it explains each step, names the expected zone, counts
/// down, shows progress, and reports the outcome. Every decision comes from
/// elsewhere — `CalibrationCoordinator` sequences, `Detection` validates taps,
/// `Calibration` computes the profile, and `Configuration` persists it.
///
/// It introduces no calibration mathematics and no heuristics of its own.
enum CalibrationCommand {

    /// How long to wait for each tap before offering a retry.
    private static let captureTimeout: TimeInterval = 6.0

    /// Countdown shown before each tap, in seconds.
    private static let countdownSeconds = 3

    static func run(arguments: [String]) {
        let composition = AppComposition()

        print("Tapper guided calibration")
        print(String(repeating: "=", count: 72))

        guard composition.capabilities().allowsRecognition else {
            print(
                "\nMicrophone access is not granted (\(composition.microphoneStatus().rawValue)).")
            print("Open Tapper.app, grant microphone access, then run calibration again.")
            return
        }

        let configuration = CalibrationConfiguration.v1
        explainProcedure(configuration: configuration)

        let source = composition.makeCaptureSource()
        do {
            try source.start()
        } catch {
            print("\nCould not start audio capture: \(error)")
            return
        }
        defer { source.stop() }

        let preferences = composition.configuration.loadPreferences().value
        let coordinator: CalibrationCoordinator
        do {
            coordinator = CalibrationCoordinator(
                session: CalibrationSession(
                    configuration: configuration,
                    deviceIdentifier: deviceIdentifier(),
                    algorithmVersion: algorithmVersion),
                detector: try TapDetector.v1(),
                buffer: composition.audioBuffer,
                samplesPerZone: configuration.samplesPerZone,
                logger: DiagnosticsLogger(
                    log: composition.diagnosticsLog, preferences: preferences))
        } catch {
            print("\nCould not prepare the detector: \(error)")
            return
        }

        print("\nSettling the microphone...")
        Thread.sleep(forTimeInterval: 1.5)

        coordinator.begin()
        collectSamples(with: coordinator, configuration: configuration)

        guard case .readyToGenerate = coordinator.state else {
            print("\nCalibration did not complete. State: \(describe(coordinator.state))")
            return
        }

        finish(coordinator: coordinator, composition: composition)
    }

    // MARK: Steps

    private static func explainProcedure(configuration: CalibrationConfiguration) {
        let total = configuration.samplesPerZone * InteractionZone.calibratable.count
        print(
            """

            What happens now
            ----------------
            Calibration learns how each corner of this Mac sounds when tapped.
            You will tap each of the four zones \(configuration.samplesPerZone) times \
            (\(total) taps total).

            For the best result:
              • put the Mac on a firm, flat surface,
              • keep the room reasonably quiet,
              • tap the same spot each time, with the same finger and force,
              • tap once per prompt — a single, deliberate tap.

            A short countdown precedes every tap. Rejected taps are simply
            retried; nothing is lost.
            """)
        print("\nPress Return when you are ready...", terminator: "")
        _ = readLine()
    }

    private static func collectSamples(
        with coordinator: CalibrationCoordinator, configuration: CalibrationConfiguration
    ) {
        for zone in InteractionZone.calibratable {
            print("\n" + String(repeating: "-", count: 72))
            print("Zone: \(displayName(zone))")
            print(String(repeating: "-", count: 72))
            print(guidance(for: zone))

            var collected = 0
            var rejections = 0
            while collected < configuration.samplesPerZone {
                guard case .collecting(let current, _) = coordinator.state, current == zone else {
                    break
                }

                countdown()
                let result = coordinator.captureSample(timeout: captureTimeout)

                switch result {
                case .accepted(_, let acceptedInZone):
                    collected = acceptedInZone
                    print("  \(progressBar(collected, of: configuration.samplesPerZone))")
                case .rejected(let reason):
                    rejections += 1
                    print("  not usable (\(reason)) — retrying")
                case .timedOut:
                    rejections += 1
                    print("  no tap detected — retrying")
                case .notCollecting:
                    return
                }
            }
            print("  \(displayName(zone)) complete — \(collected) accepted, \(rejections) retried")
        }
    }

    private static func finish(
        coordinator: CalibrationCoordinator, composition: AppComposition
    ) {
        print("\nGenerating the calibration profile...")
        switch coordinator.generateProfile() {
        case .success(let profile):
            do {
                try composition.configuration.save(profile)
            } catch {
                print("Calibration succeeded but the profile could not be saved: \(error)")
                print("State: error — recognition cannot start until a profile is stored.")
                return
            }
            print("Calibration complete. Profile saved.")
            print("  zones: \(profile.zones.count)")
            for zone in profile.zones {
                print(
                    String(
                        format: "    %-13s acceptance threshold %.4f",
                        (displayName(zone.zone) as NSString).utf8String!,
                        zone.threshold.acceptanceThreshold))
            }
            // Report readiness using the documented runtime state.
            let outcome = composition.evaluateStartup()
            let status = RuntimeStartup.status(
                for: outcome, capabilities: composition.capabilities())
            print("\nRuntime state: \(status.state.rawValue)   healthy: \(status.healthy)")
            print("You can now run validation:")
            print("  Tapper.app/Contents/MacOS/Tapper --validate")

        case .failure(let error):
            print("Calibration failed: \(describe(error))")
            print("State: failed — no profile was saved. Run calibration again.")
        }
    }

    // MARK: Presentation helpers

    private static func countdown() {
        for remaining in stride(from: countdownSeconds, through: 1, by: -1) {
            print("  tap in \(remaining)...", terminator: "\n")
            Thread.sleep(forTimeInterval: 1.0)
        }
        print("  TAP NOW")
    }

    private static func progressBar(_ collected: Int, of total: Int) -> String {
        let filled = String(repeating: "#", count: collected)
        let empty = String(repeating: ".", count: max(0, total - collected))
        return "[\(filled)\(empty)] \(collected)/\(total)"
    }

    private static func displayName(_ zone: InteractionZone) -> String {
        switch zone {
        case .topLeft: return "top left"
        case .topRight: return "top right"
        case .bottomLeft: return "bottom left"
        case .bottomRight: return "bottom right"
        case .unknown: return "unknown"
        }
    }

    private static func guidance(for zone: InteractionZone) -> String {
        "Tap the \(displayName(zone)) area of the chassis, just outside the keyboard."
    }

    private static func describe(_ state: CalibrationState) -> String {
        switch state {
        case .idle: return "idle"
        case .collecting(let zone, let accepted):
            return "collecting \(displayName(zone)) (\(accepted) accepted)"
        case .readyToGenerate: return "ready to generate"
        case .completed: return "completed"
        case .failed(let error): return "failed: \(describe(error))"
        }
    }

    private static func describe(_ error: CalibrationError) -> String {
        switch error {
        case .emptyDataset:
            return "no samples were collected"
        case .notReadyToGenerate:
            return "not every zone was completed"
        case .insufficientRetainedSamples(let retained, let required):
            return
                "too few samples survived outlier rejection (\(retained) of \(required) required) — "
                + "collect more samples"
        case .singularCovariance:
            return "the samples were too uniform to build a stable model — vary your taps slightly"
        }
    }

    private static let algorithmVersion = "1.0"

    /// A stable per-machine identifier recorded in the profile
    /// (`DATA_MODELS` §7.6 device fingerprint).
    private static func deviceIdentifier() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
}
