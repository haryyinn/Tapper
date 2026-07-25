import Audio
import Calibration
import Classification
import Commands
import Configuration
import DSP
import Detection
import Diagnostics
import Features
import Foundation
import Runtime
import os

// Tapper performance baseline harness.
//
// Measures per-stage and end-to-end latency of the deterministic recognition
// pipeline and reports the results against the binding targets.
//
// Binding targets (TRD NFR-001/NFR-002, IMPLEMENTATION_PLAN §11):
//   detection  ≤ 100 ms
//   end-to-end ≤ 200 ms
// ALGORITHM §24.3 additionally lists tighter sub-budgets; per the documentation
// precedence order those are informational here, not failing gates.
//
// This harness measures compute time on synthetic input. It does NOT measure
// recognition accuracy, sustained CPU during live listening, or real audio
// capture latency — those require a physical MacBook (see Docs note in the
// Phase 9 report).

let sampleRate = 48_000.0
let frameSize = 1920
let epoch = Date(timeIntervalSince1970: 0)

func tapFrame() -> [Double] {
    (0..<frameSize).map {
        0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
    }
}

func noiseFrame() -> [Double] {
    (0..<frameSize).map { 0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
}

/// Runs `body` `iterations` times and returns per-iteration statistics in
/// milliseconds.
func measure(
    _ label: String, iterations: Int = 1_000, warmup: Int = 100, _ body: () -> Void
) -> (label: String, mean: Double, median: Double, p95: Double, max: Double) {
    for _ in 0..<warmup { body() }
    var samples: [Double] = []
    samples.reserveCapacity(iterations)
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        samples.append(Double(end - start) / 1_000_000)
    }
    samples.sort()
    let mean = samples.reduce(0, +) / Double(samples.count)
    return (
        label,
        mean,
        samples[samples.count / 2],
        samples[Int(Double(samples.count) * 0.95)],
        samples[samples.count - 1]
    )
}

func report(
    _ result: (label: String, mean: Double, median: Double, p95: Double, max: Double),
    budget: Double? = nil
) {
    var line = String(
        format: "%-28s mean %7.4f ms   median %7.4f ms   p95 %7.4f ms   max %7.4f ms",
        (result.label as NSString).utf8String!, result.mean, result.median, result.p95, result.max)
    if let budget {
        line += String(format: "   budget %6.1f ms   %@", budget, result.p95 <= budget ? "PASS" : "FAIL")
    }
    print(line)
}

print("Tapper performance baseline")
print("machine: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("cores: \(ProcessInfo.processInfo.processorCount)")
print(String(repeating: "-", count: 110))

// MARK: Stage measurements

let frame = tapFrame()
let filter = ButterworthBandpass.v1
let dcRemoved = SignalPreprocessing.removeDCOffset(frame)
let filtered = filter.process(dcRemoved)
let (normalized, _) = SignalPreprocessing.peakNormalized(filtered)

report(measure("DC removal") { _ = SignalPreprocessing.removeDCOffset(frame) })
report(measure("band-pass filter") { _ = filter.process(dcRemoved) })
report(measure("peak normalization") { _ = SignalPreprocessing.peakNormalized(filtered) })

let hann = HannWindow(size: frameSize)
let fft = try FourierTransform(size: 2048, sampleRate: sampleRate)
let windowed = hann.apply(to: normalized)
report(measure("Hann window") { _ = hann.apply(to: normalized) })
report(measure("FFT (2048)") { _ = fft.magnitudeSpectrum(of: windowed.samples) })

let pipeline = try FeatureExtractionPipeline.v1()
report(
    measure("feature extraction (full)") { _ = pipeline.extract(from: frame) },
    budget: 10)  // ALGORITHM §24.3, informational

// MARK: Detection

var detector = try TapDetector.v1()
_ = detector.process(frame: noiseFrame(), at: epoch)
report(
    measure("detection (candidate)", iterations: 500) {
        var local = detector
        _ = local.process(frame: frame, at: epoch)
    },
    budget: 100)  // TRD NFR-001 — binding

// MARK: Classification

let dimension = FeatureVector.dimension
let identity = (0..<dimension).map { row in (0..<dimension).map { $0 == row ? 1.0 : 0.0 } }
let zones = InteractionZone.calibratable.map { zone in
    ZoneProfile(
        zone: zone,
        meanVector: MeanVector(values: [Double](repeating: 0, count: dimension)),
        covarianceMatrix: CovarianceMatrix(values: identity),
        inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
        threshold: ThresholdModel(acceptanceThreshold: 1_000_000, ambiguityMargin: 0))
}
let normalization = NormalizationParameters(
    means: [Double](repeating: 0, count: dimension),
    standardDeviations: [Double](repeating: 1, count: dimension))
let profile = CalibrationProfile(
    id: UUID(), algorithmVersion: "1.0", deviceIdentifier: "benchmark", createdAt: epoch,
    zones: zones, normalization: normalization, configuration: .v1)

guard let vector = pipeline.extract(from: frame) else { fatalError("feature extraction failed") }
let classifier = ZoneClassifier()
report(
    measure("classification") {
        _ = classifier.classify(
            featureVector: vector, profiles: zones, normalization: normalization, at: epoch)
    },
    budget: 5)  // ALGORITHM §24.3, informational

// MARK: End-to-end

final class NullProvider: CommandProvider, @unchecked Sendable {
    let commandType: CommandType = .shellCommand
    func execute(_ command: Command) -> CommandResult { .success(commandID: command.id, at: epoch) }
}

let bindings = PersistedCommandBindings(
    bindings: InteractionZone.calibratable.map {
        CommandBinding(zone: $0, command: Command(type: .shellCommand, target: "noop"))
    })

let runtimeTemplate = RecognitionRuntime(
    detector: try TapDetector.v1(),
    classifier: classifier,
    calibrationProfile: profile,
    cooldown: CooldownGate(duration: 0),
    bindings: bindings,
    executor: CommandExecutor(providers: [NullProvider()]),
    logger: DiagnosticsLogger(
        log: DiagnosticsLog(), diagnosticsEnabled: true, minimumLevel: .debug),
    recognitionLog: RecognitionLog())

// Seed the noise floor first: a runtime that has never observed a
// non-candidate frame rejects on SNR before feature extraction, which would
// measure the early-exit path instead of a full recognition.
var seededRuntime = runtimeTemplate
_ = seededRuntime.process(frame: noiseFrame(), at: epoch)

report(
    measure("end-to-end (frame->dispatch)", iterations: 500) {
        var runtime = seededRuntime
        _ = runtime.process(frame: frame, at: epoch)
    },
    budget: 200)  // TRD NFR-002 - binding

// MARK: Audio-thread write path (relevant to the ring-buffer locking question)

let ring = RollingAudioBuffer()
let block = [Float](repeating: 0.01, count: 256)
report(measure("ring write (256 frames)", iterations: 5_000) { ring.write(block, hostTime: 0) })

// Contended write, realistic cadence: the recognition worker reads one
// analysis window per hop (960 samples ≈ 20 ms at 48 kHz), not continuously.
let realisticRing = RollingAudioBuffer()
let stopRealistic = OSAllocatedUnfairLock(initialState: false)
let realisticReader = Thread {
    while !stopRealistic.withLock({ $0 }) {
        _ = realisticRing.latestSamples(1920)
        Thread.sleep(forTimeInterval: 0.020)
    }
}
realisticReader.start()
report(
    measure("ring write (realistic read)", iterations: 5_000) {
        realisticRing.write(block, hostTime: 0)
    })
stopRealistic.withLock { $0 = true }

// Contended write, pathological: a reader spinning with no pause. This is far
// more aggressive than the runtime's actual read cadence and is reported as a
// worst case, not as representative behaviour.
let spinRing = RollingAudioBuffer()
let stopSpin = OSAllocatedUnfairLock(initialState: false)
let spinReader = Thread {
    while !stopSpin.withLock({ $0 }) {
        _ = spinRing.latestSamples(1920)
    }
}
spinReader.start()
report(
    measure("ring write (spin reader)", iterations: 5_000) {
        spinRing.write(block, hostTime: 0)
    })
stopSpin.withLock { $0 = true }

print(String(repeating: "-", count: 110))
print("Audio callback budget: 256 frames @ 48 kHz = 5.33 ms; a write must stay far below it.")
print("Binding targets: detection ≤100 ms, end-to-end ≤200 ms (TRD NFR-001/002).")
print("Sub-budgets from ALGORITHM §24.3 are reported for information only.")
print("NOT measured here (requires a physical MacBook): recognition accuracy,")
print("sustained CPU during live listening, and real audio-capture latency.")
