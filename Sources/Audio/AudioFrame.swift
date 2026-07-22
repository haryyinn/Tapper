import Foundation

/// A fixed-size analysis segment extracted from captured audio
/// (`DATA_MODELS` §4.4).
///
/// Unlike ``AudioBuffer``, which may hold an arbitrary span of captured audio,
/// an `AudioFrame` is exactly one analysis window consumed by the DSP pipeline.
/// Immutable; created by the Audio subsystem.
public struct AudioFrame: Sendable, Equatable {

    /// The frame's samples (32-bit float, mono).
    public let samples: [Float]

    /// The number of samples in the frame.
    public let frameSize: Int

    /// The timestamp of the first sample in the frame.
    public let timestamp: Date

    /// Creates an audio frame.
    ///
    /// - Parameters:
    ///   - samples: The frame's samples.
    ///   - frameSize: The number of samples in the frame.
    ///   - timestamp: The timestamp of the first sample.
    public init(samples: [Float], frameSize: Int, timestamp: Date) {
        self.samples = samples
        self.frameSize = frameSize
        self.timestamp = timestamp
    }
}
