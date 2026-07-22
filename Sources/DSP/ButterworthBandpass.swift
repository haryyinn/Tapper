import Foundation

/// A 4th-order Butterworth band-pass IIR filter (`ALGORITHM` §9).
///
/// Realized as a cascade of two biquad sections designed from a 2nd-order analog
/// Butterworth low-pass prototype via the low-pass-to-band-pass transform and
/// the bilinear transform (with frequency pre-warping). The design is
/// deterministic and normalized to unity gain at the geometric center frequency.
/// For the Version 1 parameters (300–6000 Hz at 48 kHz) the −3 dB points fall
/// exactly at the specified cutoffs, and DC and Nyquist are fully rejected.
public struct ButterworthBandpass: Sendable {

    private let sections: [Biquad]

    /// The sample rate the filter was designed for, in hertz.
    public let sampleRate: Double

    /// Creates a band-pass filter for the given cutoffs and sample rate.
    ///
    /// - Parameters:
    ///   - lowCutoff: Lower −3 dB frequency, in hertz.
    ///   - highCutoff: Upper −3 dB frequency, in hertz.
    ///   - sampleRate: Sample rate, in hertz.
    public init(lowCutoff: Double, highCutoff: Double, sampleRate: Double) {
        self.sampleRate = sampleRate
        self.sections = Self.design(
            lowCutoff: lowCutoff,
            highCutoff: highCutoff,
            sampleRate: sampleRate
        )
    }

    /// The Version 1 filter: 300–6000 Hz at 48 kHz (`ALGORITHM` §9.3).
    public static let v1 = ButterworthBandpass(
        lowCutoff: 300,
        highCutoff: 6000,
        sampleRate: 48_000
    )

    /// Filters the signal, processing from zero initial state.
    ///
    /// - Parameter input: The input samples.
    /// - Returns: The band-pass-filtered samples, same length as the input.
    public func process(_ input: [Double]) -> [Double] {
        sections.reduce(input) { signal, section in section.filtered(signal) }
    }

    /// The magnitude of the frequency response at a given frequency.
    ///
    /// Exposed for validation and diagnostics.
    ///
    /// - Parameter frequency: The frequency to evaluate, in hertz.
    /// - Returns: The linear magnitude of the response.
    public func magnitudeResponse(atHz frequency: Double) -> Double {
        Self.magnitude(of: sections, atHz: frequency, sampleRate: sampleRate)
    }

    // MARK: Design

    private static func design(
        lowCutoff: Double,
        highCutoff: Double,
        sampleRate: Double
    ) -> [Biquad] {
        // Upper-half pole of the 2nd-order Butterworth low-pass prototype.
        let prototypePole = Complex(cos(3 * .pi / 4), sin(3 * .pi / 4))

        // Pre-warp the band edges for the bilinear transform.
        let warpedLow = tan(.pi * lowCutoff / sampleRate)
        let warpedHigh = tan(.pi * highCutoff / sampleRate)
        let centerSquared = warpedLow * warpedHigh
        let bandwidth = warpedHigh - warpedLow

        // Low-pass → band-pass: the prototype pole yields two band-pass poles as
        // the roots of s² − (p·BW)·s + Ω0² = 0.
        let scaledPole = prototypePole * Complex(bandwidth)
        let discriminant = (scaledPole * scaledPole) - Complex(4 * centerSquared)
        let root = discriminant.squareRoot()
        let analogPoles = [
            (scaledPole + root) / Complex(2),
            (scaledPole - root) / Complex(2),
        ]

        // Bilinear-transform each pole to the digital domain. The band-pass
        // numerator has zeros at DC and Nyquist, i.e. (1, 0, −1).
        var sections = analogPoles.map { pole -> Biquad in
            let z = (Complex(1) + pole) / (Complex(1) - pole)
            return Biquad(
                b0: 1,
                b1: 0,
                b2: -1,
                a1: -2 * z.real,
                a2: z.real * z.real + z.imaginary * z.imaginary
            )
        }

        // Normalize to unity gain at the geometric center frequency by folding
        // the scalar gain into the first section's numerator.
        let centerFrequency = (lowCutoff * highCutoff).squareRoot()
        let gain = 1.0 / magnitude(of: sections, atHz: centerFrequency, sampleRate: sampleRate)
        let first = sections[0]
        sections[0] = Biquad(
            b0: first.b0 * gain,
            b1: first.b1 * gain,
            b2: first.b2 * gain,
            a1: first.a1,
            a2: first.a2
        )
        return sections
    }

    private static func magnitude(
        of sections: [Biquad],
        atHz frequency: Double,
        sampleRate: Double
    ) -> Double {
        let omega = 2 * Double.pi * frequency / sampleRate
        let zInverse = Complex(cos(-omega), sin(-omega))
        let zInverseSquared = zInverse * zInverse
        var response = Complex(1)
        for section in sections {
            let numerator =
                Complex(section.b0) + Complex(section.b1) * zInverse + Complex(section.b2)
                * zInverseSquared
            let denominator =
                Complex(1) + Complex(section.a1) * zInverse + Complex(section.a2) * zInverseSquared
            response = response * (numerator / denominator)
        }
        return response.magnitude
    }
}
