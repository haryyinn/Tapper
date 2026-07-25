import Calibration
import Classification
import Foundation
import Runtime

/// One recorded validation trial.
///
/// `expectedZone` is `nil` for idle trials, where any recognition is a false
/// positive.
struct ValidationTrial: Codable, Sendable {

    /// Trial index within the run.
    let index: Int

    /// The zone the operator was asked to tap, or `nil` during idle recording.
    let expectedZone: String?

    /// The zone the engine reported, or `nil` if nothing was recognized.
    let detectedZone: String?

    /// The classification status, if a candidate reached classification.
    let status: String?

    /// The diagnostic confidence (0–100), if classified.
    let confidence: Double?

    /// The Mahalanobis distance, if classified.
    let distance: Double?

    /// Processing latency for the frame, in milliseconds.
    let latencyMilliseconds: Double

    /// The runtime's outcome for the frame.
    let outcome: String

    /// Whether the trial counts as a success for its kind: a tap trial matching
    /// its expected zone, or an idle trial with no recognition.
    let succeeded: Bool

    /// When the trial completed.
    let timestamp: Date
}

/// A completed validation run.
struct ValidationRun: Codable, Sendable {
    let startedAt: Date
    let completedAt: Date
    let appVersion: String
    let osVersion: String
    let trials: [ValidationTrial]
}

/// Aggregated results for a validation run.
///
/// Computes exactly the figures `VALIDATION.md` asks for. It reports what was
/// measured and never infers or extrapolates.
struct ValidationSummary {

    let perZone: [(zone: String, attempted: Int, correct: Int, misclassified: Int, missed: Int)]
    let overallAttempted: Int
    let overallCorrect: Int
    let idleOpportunities: Int
    let falsePositives: Int
    let latencies: [Double]

    /// Overall recognition accuracy, or `nil` if no tap trials were recorded.
    var overallAccuracy: Double? {
        overallAttempted > 0 ? Double(overallCorrect) / Double(overallAttempted) : nil
    }

    /// False-negative rate: tap trials that produced no recognition at all.
    var falseNegativeRate: Double? {
        guard overallAttempted > 0 else { return nil }
        let missed = perZone.reduce(0) { $0 + $1.missed }
        return Double(missed) / Double(overallAttempted)
    }

    /// False-positive rate over idle trials, or `nil` if none were recorded.
    var falsePositiveRate: Double? {
        idleOpportunities > 0 ? Double(falsePositives) / Double(idleOpportunities) : nil
    }

    /// Median processing latency in milliseconds.
    var medianLatency: Double? {
        guard !latencies.isEmpty else { return nil }
        let sorted = latencies.sorted()
        return sorted[sorted.count / 2]
    }

    /// 95th-percentile processing latency in milliseconds.
    var p95Latency: Double? {
        guard !latencies.isEmpty else { return nil }
        let sorted = latencies.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    }

    /// Builds a summary from recorded trials.
    static func make(from trials: [ValidationTrial]) -> ValidationSummary {
        let tapTrials = trials.filter { $0.expectedZone != nil }
        let idleTrials = trials.filter { $0.expectedZone == nil }

        var perZone:
            [(zone: String, attempted: Int, correct: Int, misclassified: Int, missed: Int)] = []
        for zone in InteractionZone.calibratable.map(\.rawValue) {
            let zoneTrials = tapTrials.filter { $0.expectedZone == zone }
            guard !zoneTrials.isEmpty else { continue }
            let correct = zoneTrials.filter { $0.succeeded }.count
            let missed = zoneTrials.filter { $0.detectedZone == nil }.count
            perZone.append(
                (
                    zone: zone,
                    attempted: zoneTrials.count,
                    correct: correct,
                    misclassified: zoneTrials.count - correct - missed,
                    missed: missed
                ))
        }

        return ValidationSummary(
            perZone: perZone,
            overallAttempted: tapTrials.count,
            overallCorrect: tapTrials.filter(\.succeeded).count,
            idleOpportunities: idleTrials.count,
            falsePositives: idleTrials.filter { !$0.succeeded }.count,
            latencies: trials.map(\.latencyMilliseconds)
        )
    }
}

/// Serializes validation results.
enum ValidationExport {

    /// The CSV representation, one row per trial.
    static func csv(_ run: ValidationRun) -> String {
        var lines = [
            "index,expected_zone,detected_zone,status,confidence,distance,"
                + "latency_ms,outcome,succeeded,timestamp"
        ]
        let formatter = ISO8601DateFormatter()
        for trial in run.trials {
            let fields: [String] = [
                String(trial.index),
                trial.expectedZone ?? "",
                trial.detectedZone ?? "",
                trial.status ?? "",
                trial.confidence.map { String(format: "%.4f", $0) } ?? "",
                trial.distance.map { String(format: "%.6f", $0) } ?? "",
                String(format: "%.4f", trial.latencyMilliseconds),
                trial.outcome,
                trial.succeeded ? "true" : "false",
                formatter.string(from: trial.timestamp),
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The JSON representation of the full run.
    static func json(_ run: ValidationRun) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(run)
    }

    /// A human-readable report matching the structure of `VALIDATION.md`.
    ///
    /// Targets are quoted from the governing documents and each line states
    /// whether the measurement meets it. Criteria with no data are reported as
    /// "not measured" rather than assumed.
    static func report(_ run: ValidationRun, summary: ValidationSummary) -> String {
        var out = ""
        out += "Tapper — Hardware Validation Report\n"
        out += "generated: \(ISO8601DateFormatter().string(from: run.completedAt))\n"
        out += "app version: \(run.appVersion)\n"
        out += "os: \(run.osVersion)\n"
        out += String(repeating: "=", count: 72) + "\n\n"

        out += "Per-zone accuracy (target ≥95%, ALGORITHM §24.5)\n"
        out += String(repeating: "-", count: 72) + "\n"
        if summary.perZone.isEmpty {
            out += "  not measured\n"
        }
        for row in summary.perZone {
            let accuracy = Double(row.correct) / Double(row.attempted)
            out += String(
                format: "  %-12s %3d attempted  %3d correct  %3d wrong zone  %3d missed  %6.1f%%\n",
                (row.zone as NSString).utf8String!, row.attempted, row.correct, row.misclassified,
                row.missed, accuracy * 100)
        }
        out += "\n"

        out += "Overall (prototype gate ≥80%, TRD NFR-003; release ≥95%, NFR-004)\n"
        out += String(repeating: "-", count: 72) + "\n"
        if let accuracy = summary.overallAccuracy {
            out += String(
                format: "  accuracy            %6.2f%%  (%d/%d)   prototype gate: %@\n",
                accuracy * 100, summary.overallCorrect, summary.overallAttempted,
                accuracy >= 0.80 ? "MET" : "NOT MET")
        } else {
            out += "  accuracy            not measured\n"
        }
        if let rate = summary.falseNegativeRate {
            out += String(
                format: "  false negatives     %6.2f%%   target <5%%: %@\n", rate * 100,
                rate < 0.05 ? "MET" : "NOT MET")
        } else {
            out += "  false negatives     not measured\n"
        }
        if let rate = summary.falsePositiveRate {
            out += String(
                format: "  false positives     %6.2f%%  (%d/%d)   target <1%%: %@\n", rate * 100,
                summary.falsePositives, summary.idleOpportunities, rate < 0.01 ? "MET" : "NOT MET")
        } else {
            out += "  false positives     not measured\n"
        }
        out += "\n"

        out += "Processing latency (frame → dispatch; excludes audio capture)\n"
        out += String(repeating: "-", count: 72) + "\n"
        if let median = summary.medianLatency, let p95 = summary.p95Latency {
            out += String(
                format: "  median %7.3f ms    p95 %7.3f ms    target ≤200 ms: %@\n", median, p95,
                p95 <= 200 ? "MET" : "NOT MET")
        } else {
            out += "  not measured\n"
        }
        out += "\n"

        out += "Not covered by this run (measure separately, see VALIDATION.md)\n"
        out += String(repeating: "-", count: 72) + "\n"
        out += "  sustained CPU utilisation, memory behaviour, long-duration stability,\n"
        out += "  calibration success rate, capture-inclusive end-to-end latency,\n"
        out += "  sleep/wake and permission-change reliability.\n"
        return out
    }
}
