import Foundation

/// A decay-rate estimate of one event (`ALGORITHM` §14.13).
///
/// Carries the reliability metadata §14.13.4 requires on every estimate, so a
/// consumer can tell a confident measurement from a censored or noisy one.
public struct DecayEstimate: Sendable, Equatable {

    /// The fitted time constant τ, in milliseconds.
    public let timeConstantMilliseconds: Double

    /// The span of the fitted envelope points, in decibels.
    public let fitRangeDB: Double

    /// The coefficient of determination r² of the log-envelope fit.
    public let coefficientOfDetermination: Double

    /// The number of envelope points in the fit.
    public let pointCount: Int

    /// Whether the decay met the noise floor or the end of the window before
    /// the nominal fit range was covered (§14.13.5).
    public let isCensored: Bool

    /// Creates a decay estimate.
    public init(
        timeConstantMilliseconds: Double,
        fitRangeDB: Double,
        coefficientOfDetermination: Double,
        pointCount: Int,
        isCensored: Bool
    ) {
        self.timeConstantMilliseconds = timeConstantMilliseconds
        self.fitRangeDB = fitRangeDB
        self.coefficientOfDetermination = coefficientOfDetermination
        self.pointCount = pointCount
        self.isCensored = isCensored
    }

    /// The −20 dB duration, `τ · ln(10)`, in milliseconds (§14.13.3).
    public var durationMilliseconds: Double { timeConstantMilliseconds * log(10.0) }

    /// Whether the estimate meets the empirical high-confidence criteria,
    /// `r² ≥ 0.99` and a fitted range of at least 15 dB (§14.13.4).
    ///
    /// Reported for telemetry only; no decision rests on it.
    public var isHighConfidence: Bool {
        coefficientOfDetermination >= DecayEstimator.highConfidenceR2
            && fitRangeDB >= DecayEstimator.highConfidenceRangeDB
    }
}

/// Estimates an event's decay rate by least-squares regression over its
/// log-envelope (`ALGORITHM` §14.13).
///
/// Envelope: block RMS. Fit: ordinary least squares of envelope level in dB
/// against time, over a **fixed** range from 5 dB below the envelope peak down
/// to 25 dB below it, or to 5 dB above the noise floor if that is reached
/// first. The slope gives τ; any shortfall in range is recorded, never hidden.
public struct DecayEstimator: Sendable, Equatable {

    /// Decibels lost per time constant, `20 · log10(e)`. Exact.
    public static let decibelsPerTimeConstant = 8.685889638

    /// Minimum r² for a high-confidence estimate (empirical, §14.13.4).
    public static let highConfidenceR2 = 0.99

    /// Minimum fitted range for a high-confidence estimate (empirical).
    public static let highConfidenceRangeDB = 15.0

    /// Envelope block length, in samples.
    public let blockSize: Int

    /// Envelope hop, in samples.
    public let hopSize: Int

    /// Where the fit starts, in dB below the envelope peak.
    public let fitStartDB: Double

    /// Where the fit nominally ends, in dB below the envelope peak.
    public let fitEndDB: Double

    /// Margin kept above the noise floor, in dB.
    public let noiseMarginDB: Double

    /// Creates an estimator.
    ///
    /// The defaults are the Version 1 settings of §14.13.1–2: 2 ms blocks with
    /// a 1 ms hop at 48 kHz, fitting from −5 dB to −25 dB.
    public init(
        blockSize: Int = 96,
        hopSize: Int = 48,
        fitStartDB: Double = 5,
        fitEndDB: Double = 25,
        noiseMarginDB: Double = 5
    ) {
        precondition(blockSize > 0 && hopSize > 0, "block and hop must be positive")
        self.blockSize = blockSize
        self.hopSize = hopSize
        self.fitStartDB = fitStartDB
        self.fitEndDB = fitEndDB
        self.noiseMarginDB = noiseMarginDB
    }

    /// Estimates the decay of an event.
    ///
    /// - Parameters:
    ///   - signal: The filtered, pre-normalization event window.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - noiseFloorRMS: The ambient noise-floor RMS on the same scale as
    ///     `signal`, or `nil` if unknown.
    /// - Returns: The estimate, or `nil` when the estimator declines
    ///   (§14.13.6): fewer than three points in range, zero time variance, or a
    ///   slope that is not negative.
    public func estimate(
        _ signal: [Double], sampleRate: Double, noiseFloorRMS: Double?
    ) -> DecayEstimate? {
        guard sampleRate > 0, signal.count >= blockSize else { return nil }

        // Envelope in dB, one point per hop (§14.13.1).
        var levels: [Double] = []
        levels.reserveCapacity((signal.count - blockSize) / hopSize + 1)
        var start = 0
        while start + blockSize <= signal.count {
            var sumOfSquares = 0.0
            for index in start..<(start + blockSize) {
                sumOfSquares += signal[index] * signal[index]
            }
            let rms = (sumOfSquares / Double(blockSize)).squareRoot()
            levels.append(rms > 0 ? 20 * log10(rms) : -Double.infinity)
            start += hopSize
        }
        guard let peakIndex = levels.indices.max(by: { levels[$0] < levels[$1] }),
            levels[peakIndex].isFinite
        else { return nil }

        // Fixed fit range with a noise-floor safety bound (§14.13.2).
        let peakLevel = levels[peakIndex]
        let upper = peakLevel - fitStartDB
        let target = peakLevel - fitEndDB
        var lower = target
        if let noise = noiseFloorRMS, noise > 0 {
            lower = Swift.max(target, 20 * log10(noise) + noiseMarginDB)
        }

        var fitted: [Int] = []
        var reachedLowerBound = false
        for index in (peakIndex + 1)..<levels.count where levels[index] <= upper || !fitted.isEmpty
        {
            if levels[index] < lower {
                reachedLowerBound = true
                break
            }
            fitted.append(index)
        }
        guard fitted.count >= 3 else { return nil }

        // Ordinary least squares of level against block-centre time.
        let times = fitted.map { (Double($0 * hopSize) + Double(blockSize) / 2) / sampleRate }
        let values = fitted.map { levels[$0] }
        let count = Double(fitted.count)
        let meanTime = times.reduce(0, +) / count
        let meanValue = values.reduce(0, +) / count
        var covariance = 0.0
        var timeVariance = 0.0
        var valueVariance = 0.0
        for (time, value) in zip(times, values) {
            covariance += (time - meanTime) * (value - meanValue)
            timeVariance += (time - meanTime) * (time - meanTime)
            valueVariance += (value - meanValue) * (value - meanValue)
        }
        guard timeVariance > 0 else { return nil }
        let slope = covariance / timeVariance
        guard slope < 0, valueVariance > 0 else { return nil }

        let intercept = meanValue - slope * meanTime
        var residual = 0.0
        for (time, value) in zip(times, values) {
            let error = value - (intercept + slope * time)
            residual += error * error
        }
        let rSquared = 1 - residual / valueVariance
        let tauSeconds = Self.decibelsPerTimeConstant / abs(slope)
        let range = (values.max() ?? 0) - (values.min() ?? 0)

        // Uncensored only when the decay crossed the nominal −25 dB target
        // inside the window; meeting the noise floor or the window end first
        // leaves the true duration unobserved (§14.13.5).
        let censored = !(reachedLowerBound && lower == target)

        return DecayEstimate(
            timeConstantMilliseconds: tauSeconds * 1000,
            fitRangeDB: range,
            coefficientOfDetermination: rSquared,
            pointCount: fitted.count,
            isCensored: censored
        )
    }
}
