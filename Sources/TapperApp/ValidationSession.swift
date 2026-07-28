import Calibration
import Classification
import Foundation
import Runtime

/// One recogniser's verdict for a trial (ADR-015).
///
/// Recorded per trial so the two recognisers can be compared on the same tap.
struct TrialVerdict: Codable, Sendable {

    /// The zone reported, or `nil` if nothing was recognized.
    let zone: String?

    /// The classification status.
    let status: String

    /// Diagnostic confidence (0–100).
    let confidence: Double

    /// Distance to the accepted zone, in that recogniser's own metric.
    let distance: Double

    /// The neighbours behind the decision, nearest first, as "zone@distance".
    /// Empty for recognisers that do not use neighbours.
    let neighbours: [String]
}

/// One recorded validation trial.
///
/// `expectedZone` is `nil` for idle trials, where any recognition is a false
/// positive.
///
/// The top-level `detectedZone`, `status`, `confidence` and `distance` fields
/// report the **production** (Mahalanobis) recogniser, so existing consumers of
/// this schema are unaffected. The k-NN verdict is recorded alongside it in
/// ``nearestNeighbour`` (ADR-015).
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

    /// When the target zone was first shown to the operator.
    let promptDisplayedAt: Date?

    /// When the countdown began.
    let countdownStartedAt: Date?

    /// When the tap window opened ("TAP NOW").
    let tapWindowOpenedAt: Date?

    /// When audio activity was first observed inside the window, if any. The
    /// interval from ``tapWindowOpenedAt`` is the operator's reaction time.
    let firstDetectedAudioAt: Date?

    /// When the tap window closed.
    let tapWindowClosedAt: Date?

    /// The k-NN verdict for the same feature vector, or `nil` when k-NN could
    /// not be evaluated — either no candidate reached classification, or the
    /// active profile predates ADR-015 and carries no labelled samples.
    let nearestNeighbour: TrialVerdict?

    /// The vote margin applied to the k-NN decision, recorded so a result can
    /// be reproduced.
    let voteMargin: Double?

    /// Operator reaction time in milliseconds, or `nil` if nothing was heard.
    var reactionMilliseconds: Double? {
        guard let opened = tapWindowOpenedAt, let heard = firstDetectedAudioAt else { return nil }
        return heard.timeIntervalSince(opened) * 1000
    }

    /// Whether k-NN produced the expected result for this trial, using the same
    /// rule as ``succeeded``: the expected zone for a tap trial, no recognition
    /// for an idle trial. `nil` when k-NN was not evaluated.
    var nearestNeighbourSucceeded: Bool? {
        guard let knn = nearestNeighbour else { return nil }
        return expectedZone.map { knn.zone == $0 } ?? (knn.zone == nil)
    }

    /// Whether both recognisers reached the same zone. `nil` when k-NN was not
    /// evaluated. Agreeing on "unrecognised" counts as agreement.
    var recognisersAgree: Bool? {
        nearestNeighbour.map { $0.zone == detectedZone }
    }
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

/// Compares the two recognisers over a completed run (ADR-015).
///
/// Every figure is computed from trials where both recognisers saw the same
/// feature vector, so a difference is attributable to the recogniser alone.
/// It reports what was measured and never recommends a winner.
struct RecogniserComparisonSummary {

    /// Trials in which k-NN was evaluated.
    let evaluated: Int

    /// Tap trials in which k-NN was evaluated.
    let evaluatedTaps: Int

    /// Tap trials where the production recogniser was correct.
    let mahalanobisCorrect: Int

    /// Tap trials where k-NN was correct.
    let nearestNeighbourCorrect: Int

    /// Trials where both reached the same zone.
    let agreements: Int

    /// Trials where they reached different zones.
    let disagreements: Int

    /// Disagreements broken down as (expected, mahalanobis, knn, count).
    let disagreementDetail: [(expected: String, mahalanobis: String, knn: String, count: Int)]

    /// Whether any trial had a candidate that k-NN could not evaluate because
    /// the profile carries no labelled samples.
    let unavailableForProfile: Bool

    /// Agreement rate over evaluated trials.
    var agreementRate: Double? {
        evaluated > 0 ? Double(agreements) / Double(evaluated) : nil
    }

    /// Production accuracy over the tap trials where both were evaluated.
    var mahalanobisAccuracy: Double? {
        evaluatedTaps > 0 ? Double(mahalanobisCorrect) / Double(evaluatedTaps) : nil
    }

    /// k-NN accuracy over the same tap trials.
    var nearestNeighbourAccuracy: Double? {
        evaluatedTaps > 0 ? Double(nearestNeighbourCorrect) / Double(evaluatedTaps) : nil
    }

    /// Builds the comparison from recorded trials.
    static func make(from trials: [ValidationTrial]) -> RecogniserComparisonSummary {
        let comparable = trials.filter { $0.nearestNeighbour != nil }
        let comparableTaps = comparable.filter { $0.expectedZone != nil }

        var detail: [String: (String, String, String, Int)] = [:]
        for trial in comparable where trial.recognisersAgree == false {
            let expected = trial.expectedZone ?? "(idle)"
            let maha = trial.detectedZone ?? "unrecognised"
            let knn = trial.nearestNeighbour?.zone ?? "unrecognised"
            let key = "\(expected)|\(maha)|\(knn)"
            let existing = detail[key]?.3 ?? 0
            detail[key] = (expected, maha, knn, existing + 1)
        }

        return RecogniserComparisonSummary(
            evaluated: comparable.count,
            evaluatedTaps: comparableTaps.count,
            mahalanobisCorrect: comparableTaps.filter(\.succeeded).count,
            nearestNeighbourCorrect: comparableTaps.filter { $0.nearestNeighbourSucceeded == true }
                .count,
            agreements: comparable.filter { $0.recognisersAgree == true }.count,
            disagreements: comparable.filter { $0.recognisersAgree == false }.count,
            disagreementDetail: detail.values
                .map { (expected: $0.0, mahalanobis: $0.1, knn: $0.2, count: $0.3) }
                .sorted { $0.count > $1.count },
            unavailableForProfile: trials.contains {
                $0.detectedZone != nil && $0.nearestNeighbour == nil
            }
        )
    }
}

/// Pads `text` to `width` characters, truncating if longer.
///
/// Used instead of `%s` conversions, which take a C string pointer and read
/// past the end of a Swift `String` passed directly.
func column(_ text: String, _ width: Int) -> String {
    let clipped = String(text.prefix(width - 1))
    return clipped.padding(toLength: width, withPad: " ", startingAt: 0)
}

/// Builds a confusion matrix: expected zone against reported zone.
enum ConfusionMatrix {

    /// Renders a matrix for one recogniser.
    ///
    /// - Parameters:
    ///   - trials: The trials to count. Idle trials are excluded.
    ///   - reported: The zone that recogniser reported for a trial.
    /// - Returns: Formatted lines, or a single "not measured" line.
    static func lines(
        from trials: [ValidationTrial], reported: (ValidationTrial) -> String?
    ) -> [String] {
        let taps = trials.filter { $0.expectedZone != nil }
        guard !taps.isEmpty else { return ["not measured"] }

        let zones = InteractionZone.calibratable.map(\.rawValue)
        let columns = zones + ["unrecognised"]
        var out = [
            "expected \\ reported".padding(toLength: 22, withPad: " ", startingAt: 0)
                + columns.map { $0.prefix(12).padding(toLength: 13, withPad: " ", startingAt: 0) }
                .joined()
        ]
        for zone in zones {
            let row = taps.filter { $0.expectedZone == zone }
            guard !row.isEmpty else { continue }
            var line = zone.padding(toLength: 22, withPad: " ", startingAt: 0)
            for column in columns {
                let count = row.filter { (reported($0) ?? "unrecognised") == column }.count
                line += String(count).padding(toLength: 13, withPad: " ", startingAt: 0)
            }
            out.append(line)
        }
        return out
    }
}

/// Serializes validation results.
enum ValidationExport {

    /// The CSV representation, one row per trial.
    static func csv(_ run: ValidationRun) -> String {
        var lines = [
            "index,expected_zone,detected_zone,status,confidence,distance,"
                + "latency_ms,outcome,succeeded,timestamp,"
                + "prompt_displayed_at,countdown_started_at,tap_window_opened_at,"
                + "first_detected_audio_at,tap_window_closed_at,reaction_ms,"
                + "knn_zone,knn_status,knn_confidence,knn_distance,knn_neighbours,"
                + "knn_succeeded,recognisers_agree,vote_margin"
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
                trial.promptDisplayedAt.map(formatter.string(from:)) ?? "",
                trial.countdownStartedAt.map(formatter.string(from:)) ?? "",
                trial.tapWindowOpenedAt.map(formatter.string(from:)) ?? "",
                trial.firstDetectedAudioAt.map(formatter.string(from:)) ?? "",
                trial.tapWindowClosedAt.map(formatter.string(from:)) ?? "",
                trial.reactionMilliseconds.map { String(format: "%.1f", $0) } ?? "",
                trial.nearestNeighbour?.zone ?? "",
                trial.nearestNeighbour?.status ?? "",
                trial.nearestNeighbour.map { String(format: "%.4f", $0.confidence) } ?? "",
                trial.nearestNeighbour.map { String(format: "%.6f", $0.distance) } ?? "",
                // Semicolon-separated: the field is comma-free by construction.
                trial.nearestNeighbour.map { $0.neighbours.joined(separator: ";") } ?? "",
                trial.nearestNeighbourSucceeded.map { $0 ? "true" : "false" } ?? "",
                trial.recognisersAgree.map { $0 ? "true" : "false" } ?? "",
                trial.voteMargin.map { String(format: "%.4f", $0) } ?? "",
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

    /// The recogniser-comparison section (ADR-015).
    ///
    /// Both recognisers classified the same feature vectors, so any difference
    /// below is attributable to the recogniser. The section reports the
    /// measurement and draws no conclusion about which should be adopted.
    private static func recogniserComparison(_ run: ValidationRun) -> String {
        let comparison = RecogniserComparisonSummary.make(from: run.trials)
        var out = "Recogniser comparison — Mahalanobis vs k-NN (ADR-015)\n"
        out += String(repeating: "-", count: 72) + "\n"

        guard comparison.evaluated > 0 else {
            if comparison.unavailableForProfile {
                out += "  k-NN not evaluated: the active calibration profile predates ADR-015\n"
                out += "  and carries no labelled samples. Re-run calibration to enable the\n"
                out += "  comparison. The Mahalanobis figures above are unaffected.\n\n"
            } else {
                out += "  not measured — no candidate reached classification\n\n"
            }
            return out
        }

        out += String(
            format: "  trials compared     %d  (both recognisers saw the same feature vector)\n",
            comparison.evaluated)
        if let maha = comparison.mahalanobisAccuracy, let knn = comparison.nearestNeighbourAccuracy
        {
            out += String(
                format: "  Mahalanobis         %6.2f%%  (%d/%d)\n", maha * 100,
                comparison.mahalanobisCorrect, comparison.evaluatedTaps)
            out += String(
                format: "  k-NN                %6.2f%%  (%d/%d)   vote margin %.2f\n", knn * 100,
                comparison.nearestNeighbourCorrect, comparison.evaluatedTaps,
                run.trials.compactMap(\.voteMargin).first ?? 0)
        }
        if let rate = comparison.agreementRate {
            out += String(
                format: "  agreement           %6.2f%%  (%d agree, %d disagree)\n", rate * 100,
                comparison.agreements, comparison.disagreements)
        }
        out += "\n"

        if comparison.disagreementDetail.isEmpty {
            out += "  The recognisers agreed on every compared trial.\n\n"
        } else {
            out += "  Where they disagree\n"
            out +=
                "    " + column("expected", 14) + column("Mahalanobis", 18)
                + column("k-NN", 18) + "count\n"
            for row in comparison.disagreementDetail {
                out +=
                    "    " + column(row.expected, 14) + column(row.mahalanobis, 18)
                    + column(row.knn, 18) + String(row.count) + "\n"
            }
            out += "\n"
        }

        out += "  Confusion matrix — Mahalanobis\n"
        for line in ConfusionMatrix.lines(from: run.trials, reported: \.detectedZone) {
            out += "    \(line)\n"
        }
        out += "\n"
        out += "  Confusion matrix — k-NN\n"
        for line in ConfusionMatrix.lines(from: run.trials, reported: { $0.nearestNeighbour?.zone })
        {
            out += "    \(line)\n"
        }
        out += "\n"
        out += "  Neighbours behind each k-NN decision are in the CSV (knn_neighbours),\n"
        out += "  as \"zone@distance\", nearest first.\n"
        out += "\n"
        return out
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

        out += "Operator reaction time (tap window open -> first audio)\n"
        out += String(repeating: "-", count: 72) + "\n"
        let reactions = run.trials.compactMap(\.reactionMilliseconds).sorted()
        if reactions.isEmpty {
            out += "  not measured\n"
        } else {
            let median = reactions[reactions.count / 2]
            out += String(
                format: "  median %6.0f ms   min %6.0f ms   max %6.0f ms   (n=%d)\n",
                median, reactions[0], reactions[reactions.count - 1], reactions.count)
            out += "  A long or missing reaction time means the trial measured the operator,\n"
            out += "  not the recogniser. Increase the preparation delay or tap window.\n"
        }
        out += "\n"

        out += "Outcome breakdown\n"
        out += String(repeating: "-", count: 72) + "\n"
        for line in OutcomeBreakdown.make(from: run.trials).lines() {
            out += "  \(line)\n"
        }
        out += "\n"

        out += recogniserComparison(run)

        out += "Not covered by this run (measure separately, see VALIDATION.md)\n"
        out += String(repeating: "-", count: 72) + "\n"
        out += "  sustained CPU utilisation, memory behaviour, long-duration stability,\n"
        out += "  calibration success rate, capture-inclusive end-to-end latency,\n"
        out += "  sleep/wake and permission-change reliability.\n"
        return out
    }
}

/// Counts outcomes by cause and formats them with percentages.
///
/// Used by both the validation report and the calibration report so a single
/// presentation describes why attempts did not succeed.
struct OutcomeBreakdown {

    /// Ordered entries, most frequent first, with `accepted` always first.
    let entries: [(label: String, count: Int)]

    /// Total attempts represented.
    let total: Int

    /// Builds a breakdown from validation trials.
    static func make(from trials: [ValidationTrial]) -> OutcomeBreakdown {
        var counts: [String: Int] = [:]
        for trial in trials {
            let key = trial.succeeded ? "Accepted" : trial.outcome
            counts[key, default: 0] += 1
        }
        return make(counts: counts)
    }

    /// Builds a breakdown from labelled counts.
    static func make(counts: [String: Int]) -> OutcomeBreakdown {
        let total = counts.values.reduce(0, +)
        let accepted = counts.filter { $0.key == "Accepted" }
        let rest = counts.filter { $0.key != "Accepted" }.sorted { $0.value > $1.value }
        let ordered =
            accepted.map { (label: $0.key, count: $0.value) }
            + rest.map { (label: $0.key, count: $0.value) }
        return OutcomeBreakdown(entries: ordered, total: total)
    }

    /// Formatted lines, each "Label: count (pp%)".
    func lines() -> [String] {
        guard total > 0 else { return ["no attempts recorded"] }
        return entries.map { entry in
            let percent = Double(entry.count) / Double(total) * 100
            return String(format: "%@: %d (%.1f%%)", entry.label, entry.count, percent)
        }
    }
}
