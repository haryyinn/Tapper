import Audio
import Calibration
import Configuration
import Detection
import Diagnostics
import Dispatch
import Foundation
import Runtime

/// Drives guided calibration for the user interface.
///
/// Orchestration only. It starts capture, steps the existing
/// ``Runtime/CalibrationCoordinator`` through the documented collection
/// sequence, and publishes progress for display. It contains no calibration
/// mathematics, no sample-validation rules, and no detection thresholds, and it
/// persists through `Configuration` exactly as before.
///
/// The capture call blocks while waiting for a tap, so the loop runs on a
/// dedicated queue and publishes back to the main actor.
@MainActor
final class CalibrationController: ObservableObject {

    /// What the operator is being asked to do right now.
    enum Phase: Equatable {
        case idle
        case preparing
        case countdown(zone: InteractionZone, remaining: Int)
        case listening(zone: InteractionZone)
        case finished(zones: Int)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var accepted: [InteractionZone: Int] = [:]
    @Published private(set) var retries = 0

    /// Why retries happened, counted by cause. This is the diagnostic that
    /// identifies which criterion rejects natural taps; it is reported, never
    /// acted on automatically.
    @Published private(set) var rejectionCounts: [String: Int] = [:]
    @Published private(set) var message = "Not started."
    @Published private(set) var isRunning = false

    /// Samples required per zone, from the calibration configuration.
    let samplesPerZone = CalibrationConfiguration.v1.samplesPerZone

    private let composition: AppComposition
    private let queue = DispatchQueue(label: "com.tapper.calibration-ui", qos: .userInitiated)
    private var captureSource: AVAudioEngineCaptureSource?
    private let cancellation = CancellationFlag()

    init(composition: AppComposition) {
        self.composition = composition
    }

    /// The zones in the order they are collected.
    var zones: [InteractionZone] { InteractionZone.calibratable }

    /// Every attempt by cause, accepted first, with counts and percentages.
    var breakdownLines: [String] {
        var counts = rejectionCounts
        counts["Accepted"] = accepted.values.reduce(0, +)
        return OutcomeBreakdown.make(counts: counts).lines()
    }

    /// Starts guided calibration.
    func start() {
        AppLog.calibration("Button pressed")
        guard !isRunning else {
            AppLog.calibration("Ignored: already running")
            return
        }
        guard composition.capabilities().allowsRecognition else {
            AppLog.calibration(
                "STOPPED: microphone not authorised (\(composition.microphoneStatus().rawValue))")
            message = "Microphone access is required. Use Request Microphone Access first."
            return
        }
        AppLog.calibration("Microphone authorised")

        let configuration = CalibrationConfiguration.v1
        let coordinator: CalibrationCoordinator
        let source = composition.makeCaptureSource()
        do {
            try source.start()
            AppLog.calibration("Audio capture started")
            coordinator = CalibrationCoordinator(
                session: CalibrationSession(
                    configuration: configuration,
                    deviceIdentifier: Self.deviceIdentifier(),
                    algorithmVersion: Self.algorithmVersion),
                detector: try TapDetector.v1(),
                buffer: composition.audioBuffer,
                samplesPerZone: configuration.samplesPerZone,
                logger: DiagnosticsLogger(
                    log: composition.diagnosticsLog,
                    preferences: composition.configuration.loadPreferences().value))
        } catch {
            AppLog.calibration("STOPPED: \(error)")
            message = "Could not start calibration: \(error)"
            return
        }
        AppLog.calibration("Calibration session created")

        captureSource = source
        cancellation.reset()
        isRunning = true
        accepted = [:]
        retries = 0
        rejectionCounts = [:]
        phase = .preparing
        message = "Settling the microphone..."

        let box = UncheckedBox(coordinator)
        let flag = cancellation
        queue.async { [weak self] in
            Thread.sleep(forTimeInterval: 1.5)
            guard !flag.isCancelled else {
                AppLog.calibration("STOPPED: cancelled during settle")
                return
            }
            box.value.begin()
            AppLog.calibration("Session begin -> state \(box.value.state)")
            self?.collect(using: box, configuration: configuration, cancellation: flag)
        }
    }

    /// Stops calibration without generating a profile.
    func cancel() {
        cancellation.cancel()
        finishCapture()
        isRunning = false
        phase = .idle
        message = "Calibration cancelled. Nothing was saved."
    }

    // MARK: Collection loop (background queue)

    private nonisolated func collect(
        using box: UncheckedBox<CalibrationCoordinator>, configuration: CalibrationConfiguration,
        cancellation: CancellationFlag
    ) {
        for zone in InteractionZone.calibratable {
            var collected = 0
            while collected < configuration.samplesPerZone {
                if cancellation.isCancelled { return }

                for remaining in stride(from: 3, through: 1, by: -1) {
                    publish(.countdown(zone: zone, remaining: remaining), "Get ready.")
                    Thread.sleep(forTimeInterval: 1.0)
                }
                publish(.listening(zone: zone), "Tap now.")
                AppLog.calibration("Waiting for tap: \(zone.rawValue)")

                switch box.value.captureSample(timeout: 6.0) {
                case .accepted(_, let acceptedInZone):
                    collected = acceptedInZone
                    AppLog.calibration(
                        "Sample accepted: \(zone.rawValue) \(acceptedInZone)/\(configuration.samplesPerZone)"
                    )
                    record(zone: zone, accepted: acceptedInZone, note: nil)
                case .rejected(let reason):
                    AppLog.calibration("Sample rejected: \(reason)")
                    record(
                        zone: zone, accepted: collected, note: "Not usable (\(reason)) — retry.",
                        cause: String(describing: reason))
                case .timedOut:
                    AppLog.calibration("No tap detected within timeout")
                    record(
                        zone: zone, accepted: collected, note: "No tap detected — retry.",
                        cause: "notDetected(belowDetectionThreshold)")
                case .notCollecting:
                    AppLog.calibration("STOPPED: session not collecting")
                    return
                }
            }
        }
        generate(using: box)
    }

    private nonisolated func generate(using box: UncheckedBox<CalibrationCoordinator>) {
        AppLog.calibration("All zones collected — generating profile")
        let result = box.value.generateProfile()
        Task { @MainActor in
            switch result {
            case .success(let profile):
                do {
                    try self.composition.configuration.save(profile)
                    AppLog.calibration("Profile saved (\(profile.zones.count) zones)")
                    self.writeReport(profileZones: profile.zones.count)
                    self.phase = .finished(zones: profile.zones.count)
                    self.message =
                        "Calibration complete. Profile saved for \(profile.zones.count) zones."
                } catch {
                    self.phase = .failed("save failed")
                    self.message = "Calibration succeeded but the profile could not be saved."
                }
            case .failure(let error):
                AppLog.calibration("FAILED: \(error)")
                self.writeReport(profileZones: 0, failure: String(describing: error))
                self.phase = .failed(String(describing: error))
                self.message = "Calibration failed: \(Self.describe(error)) Nothing was saved."
            }
            self.finishCapture()
            self.isRunning = false
        }
    }

    private nonisolated func publish(_ phase: Phase, _ message: String) {
        Task { @MainActor in
            self.phase = phase
            self.message = message
        }
    }

    private nonisolated func record(
        zone: InteractionZone, accepted: Int, note: String?, cause: String? = nil
    ) {
        Task { @MainActor in
            self.accepted[zone] = accepted
            if let note {
                self.retries += 1
                if let cause {
                    self.rejectionCounts[cause, default: 0] += 1
                }
                self.message = note
            } else {
                self.message = "Accepted \(accepted) of \(self.samplesPerZone)."
            }
        }
    }

    /// Writes the attempt breakdown so the calibration data survives the run.
    ///
    /// Reported only; nothing here adjusts any threshold.
    private func writeReport(profileZones: Int, failure: String? = nil) {
        var counts = rejectionCounts
        let acceptedTotal = accepted.values.reduce(0, +)
        counts["Accepted"] = acceptedTotal
        let breakdown = OutcomeBreakdown.make(counts: counts)

        var text = "Tapper — Calibration Report\n"
        text += "generated: \(ISO8601DateFormatter().string(from: Date()))\n"
        text += String(repeating: "=", count: 72) + "\n\n"
        text +=
            failure.map { "OUTCOME: failed — \($0)\n\n" }
            ?? "OUTCOME: succeeded — profile saved for \(profileZones) zones\n\n"

        text += "Accepted per zone (target \(samplesPerZone) each)\n"
        text += String(repeating: "-", count: 72) + "\n"
        for zone in zones {
            text += "  \(zone.rawValue): \(accepted[zone] ?? 0)/\(samplesPerZone)\n"
        }
        text += "\n"

        text += "Attempt breakdown (total \(breakdown.total) attempts)\n"
        text += String(repeating: "-", count: 72) + "\n"
        for line in breakdown.lines() { text += "  \(line)\n" }
        text += "\n"
        text += "The dominant non-accepted cause identifies which criterion rejects\n"
        text += "natural taps. No threshold was changed by this run.\n"

        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("TapperValidation", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            try AtomicFileStore(directory: directory)
                .write(Data(text.utf8), to: "calibration-\(stamp).txt")
            AppLog.calibration("Report written to \(directory.path)")
            message += " Report written to ~/TapperValidation."
        } catch {
            AppLog.calibration("Report could not be written: \(error)")
        }
    }

    private func finishCapture() {
        captureSource?.stop()
        captureSource = nil
    }

    // MARK: Helpers

    private static let algorithmVersion = "1.0"

    private static func deviceIdentifier() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    private static func describe(_ error: CalibrationError) -> String {
        switch error {
        case .emptyDataset: return "no samples were collected."
        case .notReadyToGenerate: return "not every zone was completed."
        case .insufficientRetainedSamples(let retained, let required):
            return "only \(retained) of \(required) samples survived outlier rejection."
        case .singularCovariance:
            return "the samples were too uniform to build a stable model."
        }
    }
}

/// Carries a reference across queue boundaries where the value is confined to a
/// single queue by construction.
final class UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
