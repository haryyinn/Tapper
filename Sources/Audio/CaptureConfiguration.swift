import Foundation

/// The microphone capture contract for Tapper's audio acquisition.
///
/// The values are fixed for Version 1 by the algorithm specification
/// (`ALGORITHM` §7.2 / §27.4): single-channel (mono), 48 kHz, 32-bit float PCM.
/// The sample format is always 32-bit float and is therefore not represented as
/// a variable here.
public struct CaptureConfiguration: Sendable, Equatable {

    /// Sampling frequency in hertz.
    public let sampleRate: Double

    /// Number of channels captured. Version 1 captures mono.
    public let channelCount: Int

    /// Creates a capture configuration.
    ///
    /// - Parameters:
    ///   - sampleRate: Sampling frequency in hertz.
    ///   - channelCount: Number of channels to capture.
    public init(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    /// The canonical Version 1 capture configuration: mono, 48 kHz.
    public static let v1 = CaptureConfiguration(sampleRate: 48_000, channelCount: 1)
}
