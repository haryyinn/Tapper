import Foundation

/// A contiguous block of raw microphone samples captured from the audio subsystem.
///
/// `AudioBuffer` is the primary input to the DSP pipeline (`DATA_MODELS` §4.3). It
/// carries only raw PCM data and the metadata required for processing, and is
/// immutable once constructed.
///
/// Ownership: created by the Audio subsystem and consumed — never modified — by
/// the DSP subsystem.
public struct AudioBuffer: Sendable, Equatable {

    /// Unique buffer identifier.
    public let id: UUID

    /// Raw PCM samples (32-bit float, mono).
    public let samples: [Float]

    /// Sampling frequency in hertz.
    public let sampleRate: Double

    /// Number of channels represented by ``samples``.
    public let channelCount: Int

    /// Capture timestamp.
    public let timestamp: Date

    /// Creates an audio buffer.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a freshly generated `UUID`.
    ///   - samples: Raw PCM samples.
    ///   - sampleRate: Sampling frequency in hertz.
    ///   - channelCount: Number of channels represented by `samples`.
    ///   - timestamp: Capture timestamp.
    public init(
        id: UUID = UUID(),
        samples: [Float],
        sampleRate: Double,
        channelCount: Int,
        timestamp: Date
    ) {
        self.id = id
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.timestamp = timestamp
    }
}

/// A validation failure for an ``AudioBuffer`` (`DATA_MODELS` §4.3).
public enum AudioBufferValidationError: Error, Equatable {

    /// The buffer contained no samples.
    case emptySamples

    /// The sample rate was not greater than zero.
    case nonPositiveSampleRate

    /// The channel count was less than one.
    case invalidChannelCount

    /// One or more samples were not finite (NaN or infinite).
    case nonFiniteSample
}

extension AudioBuffer {

    /// Validates the buffer against the canonical rules in `DATA_MODELS` §4.3.
    ///
    /// Structural fields are checked and corrupted sample data (non-finite
    /// values) is rejected, satisfying `TRD` FR-AA-007. Amplitude-range and
    /// clipping handling are signal-preprocessing concerns (`ALGORITHM` §8.2)
    /// and are intentionally out of scope for acquisition.
    ///
    /// - Throws: ``AudioBufferValidationError`` if the buffer is invalid.
    public func validate() throws {
        guard !samples.isEmpty else { throw AudioBufferValidationError.emptySamples }
        guard sampleRate > 0 else { throw AudioBufferValidationError.nonPositiveSampleRate }
        guard channelCount >= 1 else { throw AudioBufferValidationError.invalidChannelCount }
        guard samples.allSatisfy(\.isFinite) else {
            throw AudioBufferValidationError.nonFiniteSample
        }
    }

    /// Whether the buffer satisfies ``validate()``.
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
}
