/// A measurement of one frame that did not become a candidate.
///
/// Instrumentation only: recording these values never affects detection. It
/// exists to separate two causes that both present as "not detected" — a tap
/// that was genuinely quiet, and a tap whose energy fell outside the band-pass
/// and was attenuated before the detection gate saw it.
public struct NonDetectionSample: Sendable, Equatable {

    /// Peak magnitude of the DC-removed signal, before band-pass filtering.
    public let prefilterPeak: Double

    /// Peak magnitude after band-pass filtering — the value the detection gate
    /// actually tests.
    public let filteredPeak: Double

    /// Creates a sample.
    ///
    /// - Parameters:
    ///   - prefilterPeak: Peak before filtering.
    ///   - filteredPeak: Peak after filtering.
    public init(prefilterPeak: Double, filteredPeak: Double) {
        self.prefilterPeak = prefilterPeak
        self.filteredPeak = filteredPeak
    }

    /// How much of the signal survived the band-pass.
    ///
    /// A ratio near or slightly above 1 means the filter passed the energy, so a
    /// low ``filteredPeak`` reflects a genuinely quiet tap. A small ratio with a
    /// healthy ``prefilterPeak`` means the filter removed the tap's energy.
    ///
    /// Values marginally greater than 1 are expected: an IIR band-pass can
    /// overshoot on a transient, so the ratio is not bounded above by 1.
    public var attenuationRatio: Double {
        prefilterPeak > 0 ? filteredPeak / prefilterPeak : 0
    }
}

/// Aggregate statistics over non-detected frames.
public struct NonDetectionStatistics: Sendable, Equatable {

    /// Number of frames measured.
    public let count: Int

    public let medianPrefilterPeak: Double
    public let medianFilteredPeak: Double
    public let medianRatio: Double
    public let minimumRatio: Double
    public let maximumRatio: Double

    /// Highest pre-filter peak seen, indicating the loudest tap that still
    /// failed detection.
    public let maximumPrefilterPeak: Double

    /// Builds statistics from samples, or `nil` when there are none.
    ///
    /// - Parameter samples: The measured frames.
    public static func make(from samples: [NonDetectionSample]) -> NonDetectionStatistics? {
        guard !samples.isEmpty else { return nil }
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
        let ratios = samples.map(\.attenuationRatio)
        let prefilter = samples.map(\.prefilterPeak)
        return NonDetectionStatistics(
            count: samples.count,
            medianPrefilterPeak: median(prefilter),
            medianFilteredPeak: median(samples.map(\.filteredPeak)),
            medianRatio: median(ratios),
            minimumRatio: ratios.min() ?? 0,
            maximumRatio: ratios.max() ?? 0,
            maximumPrefilterPeak: prefilter.max() ?? 0
        )
    }
}
