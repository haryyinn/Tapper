import Foundation

/// Splits a continuous sample buffer into fixed-size, overlapping analysis
/// frames (`ALGORITHM` §11).
///
/// Version 1 uses 1920-sample frames (40 ms at 48 kHz) with 50% overlap (a hop
/// of 960 samples). This produces the ``AudioFrame`` values the DSP pipeline
/// consumes. Frame *scheduling* in real time is a later concern; this type only
/// performs the deterministic split.
public struct AnalysisFrameExtractor: Sendable {

    /// The number of samples per frame.
    public let frameSize: Int

    /// The number of samples advanced between consecutive frames.
    public let hopSize: Int

    /// Creates a frame extractor.
    ///
    /// - Parameters:
    ///   - frameSize: Samples per frame. Must be positive.
    ///   - hopSize: Samples advanced between frames. Must be positive.
    public init(frameSize: Int, hopSize: Int) {
        precondition(frameSize > 0, "frameSize must be positive")
        precondition(hopSize > 0, "hopSize must be positive")
        self.frameSize = frameSize
        self.hopSize = hopSize
    }

    /// The Version 1 windowing: 1920-sample frames with 50% overlap.
    public static let v1 = AnalysisFrameExtractor(frameSize: 1920, hopSize: 960)

    /// Splits a sample buffer into overlapping frames.
    ///
    /// Frames start at offsets 0, `hopSize`, 2·`hopSize`, … while a full frame
    /// fits. A buffer shorter than one frame yields no frames.
    ///
    /// - Parameters:
    ///   - samples: The continuous sample buffer.
    ///   - startTimestamp: The timestamp of the buffer's first sample.
    ///   - sampleRate: The sample rate, in hertz, used to timestamp each frame.
    /// - Returns: The overlapping frames, in order.
    public func frames(
        from samples: [Float],
        startTimestamp: Date,
        sampleRate: Double
    ) -> [AudioFrame] {
        guard samples.count >= frameSize else { return [] }
        var frames: [AudioFrame] = []
        var offset = 0
        while offset + frameSize <= samples.count {
            let slice = Array(samples[offset..<(offset + frameSize)])
            let timestamp = startTimestamp.addingTimeInterval(Double(offset) / sampleRate)
            frames.append(AudioFrame(samples: slice, frameSize: frameSize, timestamp: timestamp))
            offset += hopSize
        }
        return frames
    }
}
