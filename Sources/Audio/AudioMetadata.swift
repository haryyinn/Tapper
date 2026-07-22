import Foundation

/// Descriptive information about the audio acquisition environment
/// (`DATA_MODELS` §4.5).
///
/// `AudioMetadata` contains no audio samples and shall not participate in
/// recognition decisions. It supports diagnostics, calibration reports, and
/// compatibility verification.
public struct AudioMetadata: Sendable, Equatable {

    /// Human-readable input device name.
    public let inputDevice: String

    /// Sampling frequency in hertz.
    public let sampleRate: Double

    /// Number of channels.
    public let channelCount: Int

    /// Sample bit depth (32 for float PCM).
    public let bitDepth: Int

    /// Time the capture context was established.
    public let captureTimestamp: Date

    /// Creates audio metadata.
    ///
    /// - Parameters:
    ///   - inputDevice: Human-readable input device name.
    ///   - sampleRate: Sampling frequency in hertz.
    ///   - channelCount: Number of channels.
    ///   - bitDepth: Sample bit depth.
    ///   - captureTimestamp: Time the capture context was established.
    public init(
        inputDevice: String,
        sampleRate: Double,
        channelCount: Int,
        bitDepth: Int,
        captureTimestamp: Date
    ) {
        self.inputDevice = inputDevice
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.captureTimestamp = captureTimestamp
    }
}
