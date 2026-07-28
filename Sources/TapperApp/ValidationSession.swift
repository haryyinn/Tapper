import Calibration
import Classification
import Foundation
import Runtime

/// One recogniser's verdict for a trial (`DATA_MODELS` §7.13a).
///
/// Recorded per trial so every benchmark recogniser can be compared on the same
/// tap, and so the acceptance radius can be assessed later from measurement
/// rather than argument (`ALGORITHM` §17.25.6).
struct RecogniserVerdictRecord: Codable, Sendable {

    /// The benchmark identifier (`ALGORITHM` §17.25.2).
    let recogniser: String

    /// The zone reported, or `nil` if nothing was recognized.
    let zone: String?

    /// The classification status.
    let status: String

    /// Diagnostic confidence (0–100).
    let confidence: Double

    /// Distance to the winning zone, in that recogniser's own metric.
    let distance: Double

    /// The acceptance radius this distance was tested against.
    let acceptanceRadius: Double

    /// `acceptanceRadius − distance`. Negative when the tap fell outside the
    /// radius. This is the figure that decides whether the radius formula is
    /// appropriate.
    let acceptanceMargin: Double

    /// Whether the tap was accepted as a zone.
    let accepted: Bool

    /// Classification latency, in microseconds, excluding model preparation.
    let latencyMicroseconds: Double

    /// The neighbours behind the decision, nearest first, as "zone@distance".
    /// Empty for recognisers that do not consult individual samples.
    let neighbours: [String]
}

/// One recorded validation trial.
///
/// `expectedZone` is `nil` for idle trials, where any recognition is a false
/// positive.
///
/// The top-level `detectedZone`, `status`, `confidence` and `distance` fields
/// report what the **runtime** did — the production recogniser's verdict, and
/// the outcome the engine actually sequenced. Every benchmark recogniser's
/// verdict, including production's own re-measured one, is in ``verdicts``
/// (ADR-016).
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

    /// The normalized feature vector that produced this trial, or `nil` when no
    /// candidate reached classification.
    ///
    /// Recorded so an unknown or misclassified tap can be located in feature
    /// space against the calibration samples it failed to match (ADR-016).
    let featureVector: [Double]?

    /// One entry per benchmark recogniser evaluated (`ALGORITHM` §17.25).
    ///
    /// Empty when no candidate reached classification. A recogniser that could
    /// not be evaluated is **absent** rather than present with a failed
    /// verdict, so "not evaluated" stays distinguishable from "evaluated and
    /// rejected" (`DATA_MODELS` §7.13a).
    let verdicts: [RecogniserVerdictRecord]

    /// Operator reaction time in milliseconds, or `nil` if nothing was heard.
    var reactionMilliseconds: Double? {
        guard let opened = tapWindowOpenedAt, let heard = firstDetectedAudioAt else { return nil }
        return heard.timeIntervalSince(opened) * 1000
    }

    /// The verdict from one recogniser, if it was evaluated for this trial.
    func verdict(from recogniser: String) -> RecogniserVerdictRecord? {
        verdicts.first { $0.recogniser == recogniser }
    }

    /// Whether a recogniser produced the expected result, using the same rule
    /// as ``succeeded``: the expected zone for a tap trial, no recognition for
    /// an idle trial. `nil` when that recogniser was not evaluated.
    func succeeded(for recogniser: String) -> Bool? {
        guard let verdict = verdict(from: recogniser) else { return nil }
        return expectedZone.map { verdict.zone == $0 } ?? (verdict.zone == nil)
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

/// Per-recogniser metrics over a completed run (`ALGORITHM` §17.25.5).
///
/// Every figure is computed from trials where the recognisers saw the identical
/// feature vector, so a difference is attributable to the recogniser alone.
/// It reports what was measured and never recommends a winner: promotion is an
/// explicit decision, not a benchmark outcome (ADR-016).
struct RecogniserMetrics {

    /// The benchmark identifier.
    let identifier: String

    /// Tap trials where this recogniser was evaluated.
    let attempted: Int

    /// Tap trials it identified correctly.
    let correct: Int

    /// Tap trials it assigned to the wrong zone.
    let misclassified: Int

    /// Tap trials it did not recognise at all — false negatives.
    let falseNegatives: Int

    /// Tap trials it reported as `unknown` or `ambiguous`.
    let unknowns: Int

    /// Idle trials in which it reported a zone — false positives.
    let falsePositives: Int

    /// Idle trials in which it was evaluated.
    let idleOpportunities: Int

    /// Per-zone attempted and correct counts, canonical order.
    let perZone: [(zone: String, attempted: Int, correct: Int)]

    /// Classification latencies, in microseconds.
    let latencies: [Double]

    /// Acceptance margins (radius − distance) over accepted taps.
    let acceptedMargins: [Double]

    /// Acceptance margins over taps rejected on distance.
    let rejectedMargins: [Double]

    var accuracy: Double? {
        attempted > 0 ? Double(correct) / Double(attempted) : nil
    }

    var unknownRate: Double? {
        attempted > 0 ? Double(unknowns) / Double(attempted) : nil
    }

    var falseNegativeRate: Double? {
        attempted > 0 ? Double(falseNegatives) / Double(attempted) : nil
    }

    var falsePositiveRate: Double? {
        idleOpportunities > 0 ? Double(falsePositives) / Double(idleOpportunities) : nil
    }

    var medianLatency: Double? {
        guard !latencies.isEmpty else { return nil }
        let sorted = latencies.sorted()
        return sorted[sorted.count / 2]
    }

    var p95Latency: Double? {
        guard !latencies.isEmpty else { return nil }
        let sorted = latencies.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    }

    /// Builds metrics for one recogniser.
    static func make(identifier: String, from trials: [ValidationTrial]) -> RecogniserMetrics {
        let evaluated = trials.filter { $0.verdict(from: identifier) != nil }
        let taps = evaluated.filter { $0.expectedZone != nil }
        let idle = evaluated.filter { $0.expectedZone == nil }

        var perZone: [(zone: String, attempted: Int, correct: Int)] = []
        for zone in InteractionZone.calibratable.map(\.rawValue) {
            let rows = taps.filter { $0.expectedZone == zone }
            guard !rows.isEmpty else { continue }
            perZone.append(
                (zone, rows.count, rows.filter { $0.succeeded(for: identifier) == true }.count))
        }

        let tapVerdicts = taps.compactMap { $0.verdict(from: identifier) }
        return RecogniserMetrics(
            identifier: identifier,
            attempted: taps.count,
            correct: taps.filter { $0.succeeded(for: identifier) == true }.count,
            misclassified: taps.filter {
                guard let verdict = $0.verdict(from: identifier), let zone = verdict.zone
                else { return false }
                return zone != $0.expectedZone
            }.count,
            falseNegatives: taps.filter { $0.verdict(from: identifier)?.zone == nil }.count,
            unknowns: tapVerdicts.filter { !$0.accepted }.count,
            falsePositives: idle.filter { $0.verdict(from: identifier)?.zone != nil }.count,
            idleOpportunities: idle.count,
            perZone: perZone,
            latencies: evaluated.compactMap { $0.verdict(from: identifier)?.latencyMicroseconds },
            acceptedMargins: tapVerdicts.filter(\.accepted).map(\.acceptanceMargin),
            rejectedMargins: tapVerdicts.filter { !$0.accepted }.map(\.acceptanceMargin)
        )
    }
}

/// The set of recognisers that appear anywhere in a run, in first-seen order.
///
/// Derived from the data rather than assumed, so a run recorded against a
/// profile that could not support every recogniser reports exactly those that
/// were evaluated.
func evaluatedRecognisers(in trials: [ValidationTrial]) -> [String] {
    var seen: [String] = []
    for trial in trials {
        for verdict in trial.verdicts where !seen.contains(verdict.recogniser) {
            seen.append(verdict.recogniser)
        }
    }
    return seen
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
    /// Counts only trials where that recogniser was actually evaluated, so the
    /// row totals equal the `attempted` figure reported for it. A trial in
    /// which no candidate reached classification is not a rejection by any
    /// recogniser and must not be charged to one (`DATA_MODELS` §7.13a).
    ///
    /// - Parameters:
    ///   - trials: The trials to count. Idle trials are excluded.
    ///   - recogniser: The benchmark identifier to report on.
    /// - Returns: Formatted lines, or a single "not measured" line.
    static func lines(from trials: [ValidationTrial], recogniser: String) -> [String] {
        let reported: (ValidationTrial) -> String? = { $0.verdict(from: recogniser)?.zone }
        let taps = trials.filter { $0.expectedZone != nil && $0.verdict(from: recogniser) != nil }
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

    /// The CSV representation, one row per trial per evaluated recogniser
    /// (`ALGORITHM` §17.25.6).
    ///
    /// Expanding the rows this way keeps every acceptance measurement — the
    /// distance, the radius it was tested against, and their difference — in
    /// its own row, so the radius formula can be assessed directly from the
    /// file. Trials where no candidate reached classification appear once with
    /// an empty recogniser column, so they are not silently dropped.
    static func csv(_ run: ValidationRun) -> String {
        var lines = [
            "index,expected_zone,detected_zone,status,confidence,distance,"
                + "latency_ms,outcome,succeeded,timestamp,"
                + "prompt_displayed_at,countdown_started_at,tap_window_opened_at,"
                + "first_detected_audio_at,tap_window_closed_at,reaction_ms,"
                + "recogniser,rec_zone,rec_status,rec_confidence,rec_distance,"
                + "rec_acceptance_radius,rec_acceptance_margin,rec_accepted,"
                + "rec_latency_us,rec_neighbours,rec_succeeded,feature_vector"
        ]
        let formatter = ISO8601DateFormatter()
        for trial in run.trials {
            let shared: [String] = [
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
            ]
            // Semicolon-separated: these fields must stay comma-free.
            let vector =
                trial.featureVector.map {
                    $0.map { String(format: "%.6f", $0) }
                        .joined(separator: ";")
                } ?? ""

            guard !trial.verdicts.isEmpty else {
                lines.append(
                    (shared + [String](repeating: "", count: 11) + [vector])
                        .joined(separator: ","))
                continue
            }
            for verdict in trial.verdicts {
                let fields: [String] = [
                    verdict.recogniser,
                    verdict.zone ?? "",
                    verdict.status,
                    String(format: "%.4f", verdict.confidence),
                    String(format: "%.6f", verdict.distance),
                    String(format: "%.6f", verdict.acceptanceRadius),
                    String(format: "%.6f", verdict.acceptanceMargin),
                    verdict.accepted ? "true" : "false",
                    String(format: "%.2f", verdict.latencyMicroseconds),
                    verdict.neighbours.joined(separator: ";"),
                    trial.succeeded(for: verdict.recogniser).map { $0 ? "true" : "false" } ?? "",
                    vector,
                ]
                lines.append((shared + fields).joined(separator: ","))
            }
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

    /// The recogniser-benchmark section (`ALGORITHM` §17.25.5, ADR-016).
    ///
    /// Every recogniser classified the same feature vectors, so any difference
    /// below is attributable to the recogniser. The section reports the
    /// measurement and names no winner: promotion is an explicit decision, not
    /// a benchmark outcome.
    private static func recogniserBenchmark(_ run: ValidationRun) -> String {
        let identifiers = evaluatedRecognisers(in: run.trials)
        var out = "Recogniser benchmark (ALGORITHM §17.25, ADR-016)\n"
        out += String(repeating: "-", count: 72) + "\n"

        guard !identifiers.isEmpty else {
            out += "  not measured — no candidate reached classification\n\n"
            return out
        }

        out += "  Production recogniser is mahalanobis. Every other row is experimental\n"
        out += "  and was evaluated only; no result here promotes a recogniser.\n\n"

        let metrics = identifiers.map { RecogniserMetrics.make(identifier: $0, from: run.trials) }

        out +=
            "  " + column("recogniser", 18) + column("accuracy", 11) + column("unknown", 10)
            + column("false neg", 11) + column("false pos", 11) + column("median µs", 11)
            + "p95 µs\n"
        for metric in metrics {
            out += "  " + column(metric.identifier, 18)
            out += column(
                metric.accuracy.map { String(format: "%.1f%%", $0 * 100) } ?? "—", 11)
            out += column(
                metric.unknownRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—", 10)
            out += column(
                metric.falseNegativeRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—", 11)
            out += column(
                metric.falsePositiveRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—", 11)
            out += column(metric.medianLatency.map { String(format: "%.1f", $0) } ?? "—", 11)
            out += (metric.p95Latency.map { String(format: "%.1f", $0) } ?? "—") + "\n"
        }
        out += "\n"
        out += "  accuracy over tap trials where that recogniser was evaluated;\n"
        out += "  false positives over idle trials. A recogniser absent from a trial was\n"
        out += "  not evaluated there and is excluded from its own denominators.\n\n"

        if identifiers.contains("knn-1") {
            out += "  Note: at k=1 the vote margin is degenerate — one neighbour holds the\n"
            out += "  entire vote weight — so only distance acceptance rejects (§17.25.2).\n\n"
        }

        out += "  Per-zone accuracy\n"
        out +=
            "    " + column("recogniser", 18)
            + InteractionZone.calibratable.map { column($0.rawValue, 14) }.joined() + "\n"
        for metric in metrics {
            out += "    " + column(metric.identifier, 18)
            for zone in InteractionZone.calibratable.map(\.rawValue) {
                let row = metric.perZone.first { $0.zone == zone }
                let text =
                    row.map {
                        String(
                            format: "%.0f%% (%d/%d)",
                            Double($0.correct)
                                / Double($0.attempted) * 100, $0.correct, $0.attempted)
                    } ?? "—"
                out += column(text, 14)
            }
            out += "\n"
        }
        out += "\n"

        out += acceptanceInstrumentation(metrics)

        for identifier in identifiers {
            out += "  Confusion matrix — \(identifier)\n"
            for line in ConfusionMatrix.lines(from: run.trials, recogniser: identifier) {
                out += "    \(line)\n"
            }
            out += "\n"
        }

        out += disagreements(run.trials, identifiers: identifiers)

        out += "  Per-tap distances, radii, margins and neighbours are in the CSV.\n\n"
        return out
    }

    /// The acceptance-radius instrumentation (`ALGORITHM` §17.25.6).
    ///
    /// Reports how much room each acceptance had, and how far each rejection
    /// missed by, so the radius formula can later be assessed from data. It
    /// draws no conclusion and changes no threshold.
    private static func acceptanceInstrumentation(_ metrics: [RecogniserMetrics]) -> String {
        var out = "  Acceptance radius instrumentation (§17.25.6 — measurement only)\n"
        out +=
            "    " + column("recogniser", 18) + column("accepted n", 12)
            + column("margin med", 12) + column("margin min", 12) + column("rejected n", 12)
            + "overshoot med\n"
        for metric in metrics {
            let accepted = metric.acceptedMargins.sorted()
            let rejected = metric.rejectedMargins.sorted()
            out += "    " + column(metric.identifier, 18)
            out += column(String(accepted.count), 12)
            out += column(
                accepted.isEmpty ? "—" : String(format: "%.4f", accepted[accepted.count / 2]), 12)
            out += column(accepted.isEmpty ? "—" : String(format: "%.4f", accepted[0]), 12)
            out += column(String(rejected.count), 12)
            // Rejected margins are negative; report how far outside the radius.
            out +=
                rejected.isEmpty
                ? "—" : String(format: "%.4f", -rejected[rejected.count / 2])
            out += "\n"
        }
        out += "\n"
        out += "    margin = radius − distance. A small positive median means acceptances\n"
        out += "    only just fit; a small overshoot means rejections only just missed.\n"
        out += "    Either indicates the radius is close to the decisions it governs.\n\n"
        return out
    }

    /// Trials where the recognisers did not all reach the same zone.
    private static func disagreements(
        _ trials: [ValidationTrial], identifiers: [String]
    ) -> String {
        guard identifiers.count > 1 else { return "" }
        var out = "  Where the recognisers disagree\n"

        let rows = trials.filter { trial in
            let zones = identifiers.compactMap { trial.verdict(from: $0) }.map { $0.zone ?? "—" }
            return Set(zones).count > 1
        }
        guard !rows.isEmpty else {
            out += "    They agreed on every evaluated trial.\n\n"
            return out
        }

        out +=
            "    " + column("trial", 7) + column("expected", 14)
            + identifiers.map { column($0, 18) }.joined() + "\n"
        for trial in rows.prefix(40) {
            out +=
                "    " + column(String(trial.index), 7)
                + column(trial.expectedZone ?? "(idle)", 14)
            for identifier in identifiers {
                out += column(trial.verdict(from: identifier)?.zone ?? "—", 18)
            }
            out += "\n"
        }
        if rows.count > 40 {
            out += "    … \(rows.count - 40) more, see the CSV\n"
        }
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

        out += recogniserBenchmark(run)

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
