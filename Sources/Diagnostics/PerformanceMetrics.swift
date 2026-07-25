import Foundation

/// Quantitative measurements describing runtime performance
/// (`DATA_MODELS` §11.5).
///
/// A plain immutable value populated by the runtime layer, which owns the
/// measurements (§11.9). Diagnostics defines and validates the model but does
/// not sample the system: no CPU or memory acquisition method is documented, so
/// none is invented here.
public struct PerformanceMetrics: Sendable, Equatable, Codable {

    /// Total recognition latency, in seconds.
    public let processingLatency: TimeInterval

    /// DSP execution time, in seconds.
    public let dspLatency: TimeInterval

    /// Classification execution time, in seconds.
    public let classificationLatency: TimeInterval

    /// CPU utilization, as a percentage in the range 0–100.
    public let cpuUsage: Double

    /// Memory consumption, in megabytes.
    public let memoryUsage: Double

    /// Creates performance metrics.
    public init(
        processingLatency: TimeInterval,
        dspLatency: TimeInterval,
        classificationLatency: TimeInterval,
        cpuUsage: Double,
        memoryUsage: Double
    ) {
        self.processingLatency = processingLatency
        self.dspLatency = dspLatency
        self.classificationLatency = classificationLatency
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }

    /// Whether the metrics satisfy `DATA_MODELS` §11.10 (latencies ≥ 0, CPU
    /// usage within range, memory ≥ 0, all values finite).
    public var isValid: Bool {
        let values = [
            processingLatency, dspLatency, classificationLatency, cpuUsage, memoryUsage,
        ]
        guard values.allSatisfy(\.isFinite) else { return false }
        return processingLatency >= 0 && dspLatency >= 0 && classificationLatency >= 0
            && (0...100).contains(cpuUsage) && memoryUsage >= 0
    }
}
