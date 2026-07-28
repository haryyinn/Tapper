import Calibration
import Foundation
import Inspection

// Offline developer utility for inspecting the labelled calibration dataset
// (ADR-016 §5).
//
// It is not part of the application: it performs no audio capture, requires no
// permissions, and cannot modify a profile. It reads a calibration profile and,
// optionally, a validation run, and writes a static report and plot.

/// The trial fields this tool reads from an exported validation run.
///
/// Declared independently of the application's own type so the tool stays
/// decoupled from it: unknown keys are ignored, and a schema addition on the
/// application side cannot break inspection of an older file.
private struct ExportedTrial: Decodable {
    let expectedZone: String?
    let featureVector: [Double]?
    let verdicts: [ExportedVerdict]?
}

private struct ExportedVerdict: Decodable {
    let recogniser: String
    let zone: String?
}

private struct ExportedRun: Decodable {
    let trials: [ExportedTrial]
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("tapper-inspect: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2, arguments[1] != "--help", arguments[1] != "-h" else {
    print(
        """
        Inspects the labelled calibration dataset in feature space.

          tapper-inspect <profile.json> [validation-run.json] [--recogniser <id>]
                         [--out <directory>]

        Writes feature-space.svg and feature-space.txt. Defaults: the run's own
        directory for --out, and "mahalanobis" for --recogniser.

        Developer diagnostic. It reads files and writes a report; it does not
        capture audio, require permissions, or modify any profile.
        """)
    exit(arguments.count >= 2 ? 0 : 1)
}

let profilePath = arguments[1]
var runPath: String?
var recogniserIdentifier = "mahalanobis"
var outputDirectory: String?

var index = 2
while index < arguments.count {
    switch arguments[index] {
    case "--recogniser":
        index += 1
        guard index < arguments.count else { fail("--recogniser needs a value") }
        recogniserIdentifier = arguments[index]
    case "--out":
        index += 1
        guard index < arguments.count else { fail("--out needs a value") }
        outputDirectory = arguments[index]
    default:
        if runPath == nil {
            runPath = arguments[index]
        } else {
            fail("unexpected argument: \(arguments[index])")
        }
    }
    index += 1
}

// MARK: Load

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

guard let profileData = FileManager.default.contents(atPath: profilePath) else {
    fail("cannot read profile at \(profilePath)")
}
let profile: CalibrationProfile
do {
    profile = try decoder.decode(CalibrationProfile.self, from: profileData)
} catch {
    fail("cannot decode profile: \(error)")
}

let withSamples = profile.zones.filter { !$0.samples.isEmpty }
guard !withSamples.isEmpty else {
    fail(
        """
        this profile carries no labelled samples, so there is no dataset to inspect.
        It predates ADR-015. Re-run calibration to produce an inspectable profile.
        """)
}

var points: [InspectionPoint] = []
var samplesByZone: [String: [[Double]]] = [:]
for zone in withSamples {
    samplesByZone[zone.zone.rawValue] = zone.samples
    for sample in zone.samples {
        points.append(
            InspectionPoint(
                zone: zone.zone.rawValue, reportedZone: nil, kind: .calibration, vector: sample))
    }
}

var validationTaps = 0
if let runPath {
    guard let runData = FileManager.default.contents(atPath: runPath) else {
        fail("cannot read validation run at \(runPath)")
    }
    let run: ExportedRun
    do {
        run = try decoder.decode(ExportedRun.self, from: runData)
    } catch {
        fail("cannot decode validation run: \(error)")
    }

    for trial in run.trials {
        guard let vector = trial.featureVector, let expected = trial.expectedZone else { continue }
        guard vector.count == profile.normalization.means.count else { continue }
        let reported = trial.verdicts?.first { $0.recogniser == recogniserIdentifier }?.zone
        let kind: InspectionPoint.Kind =
            reported == nil ? .unknown : (reported == expected ? .correct : .misclassified)
        points.append(
            InspectionPoint(
                zone: expected, reportedZone: reported, kind: kind, vector: vector))
        validationTaps += 1
    }
}

// MARK: Project

guard let pca = PrincipalComponentAnalysis(fitting: points.map(\.vector)) else {
    fail("not enough samples to fit a projection")
}
let captured = pca.capturedVariance(through: 2)
let projected = points.map { point -> (point: InspectionPoint, x: Double, y: Double) in
    let coordinates = pca.project(point.vector, onto: 2)
    return (point, coordinates[0], coordinates.count > 1 ? coordinates[1] : 0)
}

// MARK: Report

let report = FeatureSpaceReport.make(samplesByZone: samplesByZone)
let zoneNames = report.zones.map(\.zone)

func pad(_ text: String, _ width: Int) -> String {
    String(text.prefix(width - 1)).padding(toLength: width, withPad: " ", startingAt: 0)
}

var text = "Tapper — Feature Space Inspection\n"
text += "profile:   \(profilePath)\n"
text += runPath.map { "run:       \($0)  (recogniser: \(recogniserIdentifier))\n" } ?? ""
text += "generated: \(ISO8601DateFormatter().string(from: Date()))\n"
text += String(repeating: "=", count: 72) + "\n\n"

text += "Dataset\n" + String(repeating: "-", count: 72) + "\n"
text += "  calibration samples: \(points.filter { $0.kind == .calibration }.count)\n"
text += "  validation taps:     \(validationTaps)\n"
text += "  dimensions:          \(pca.mean.count)\n\n"

text += "Projection fidelity\n" + String(repeating: "-", count: 72) + "\n"
text += String(format: "  first two components carry %.1f%% of total variance\n", captured * 100)
for (position, value) in pca.eigenvalues.prefix(5).enumerated() {
    let share = pca.totalVariance > 0 ? value / pca.totalVariance * 100 : 0
    text += String(format: "    PC%d  variance %10.5f  (%5.1f%%)\n", position + 1, value, share)
}
text += "\n"
if captured < 0.7 {
    text += "  The plot omits a large share of the structure. Read cluster separation\n"
    text += "  in it as suggestive only; the distances the recogniser uses are those\n"
    text += "  of the full space, reported below.\n\n"
}

text += "Per-zone spread (full space, normalized units)\n"
text += String(repeating: "-", count: 72) + "\n"
text +=
    "  " + pad("zone", 16) + pad("n", 6) + pad("mean radius", 14) + pad("max radius", 14)
    + "outliers\n"
for zone in report.zones {
    text += "  " + pad(zone.zone, 16) + pad(String(zone.count), 6)
    text += pad(String(format: "%.4f", zone.meanRadius), 14)
    text += pad(String(format: "%.4f", zone.maximumRadius), 14)
    text += "\(zone.outliers)\n"
}
text += "\n  outliers are samples further than mean + 2σ from their own centroid.\n\n"

text += "Zone separation (full space)\n" + String(repeating: "-", count: 72) + "\n"
text +=
    "  " + pad("pair", 30) + pad("centroid dist", 16) + pad("combined spread", 18)
    + "ratio\n"
for pair in report.pairs {
    text += "  " + pad("\(pair.first) ↔ \(pair.second)", 30)
    text += pad(String(format: "%.4f", pair.centroidDistance), 16)
    text += pad(String(format: "%.4f", pair.combinedSpread), 18)
    text += String(format: "%.2f\n", pair.separation)
}
text += "\n"
text += "  ratio = centroid distance / combined mean spread. Below 1.0 the two\n"
text += "  clusters' typical extents reach past each other, which is where\n"
text += "  confusion between those zones would be expected.\n\n"

let overlapping = report.pairs.filter { $0.separation < 1.0 }
if overlapping.isEmpty {
    text += "  No zone pair overlaps by this measure.\n"
} else {
    text +=
        "  Overlapping pairs: "
        + overlapping.map { "\($0.first)↔\($0.second)" }.joined(separator: ", ") + "\n"
}
text += "\nThis report describes geometry. It recommends no change.\n"

// MARK: Write

let directory =
    outputDirectory
    ?? (runPath.map { ($0 as NSString).deletingLastPathComponent }
        ?? (profilePath as NSString).deletingLastPathComponent)
let target = directory.isEmpty ? "." : directory

do {
    try FileManager.default.createDirectory(
        atPath: target, withIntermediateDirectories: true)
    let svg = ScatterPlotSVG.render(
        points: projected, zones: zoneNames, capturedVariance: captured)
    try Data(svg.utf8).write(to: URL(fileURLWithPath: "\(target)/feature-space.svg"))
    try Data(text.utf8).write(to: URL(fileURLWithPath: "\(target)/feature-space.txt"))
} catch {
    fail("cannot write output: \(error)")
}

print(text)
print("wrote \(target)/feature-space.svg")
print("wrote \(target)/feature-space.txt")
