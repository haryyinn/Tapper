import AVFoundation
import Foundation
import os

/// An ``AudioCaptureSource`` backed by `AVAudioEngine`.
///
/// Installs a tap on the input node and continuously writes captured mono float
/// samples into a ``RollingAudioBuffer``. The tap runs on the real-time audio
/// thread and performs only a bounded copy into the ring — no allocation, I/O,
/// or other work (`IMPLEMENTATION_RULES` §Threading). Samples are captured at the
/// input node's native format, which is 48 kHz on the supported Apple Silicon
/// hardware (`ALGORITHM` §7.2, `DSP_PARAMETERS` §1).
///
/// The requested tap buffer size is only a hint; the delivered block size is not
/// assumed to be fixed, and the ring buffer is the authoritative store.
public final class AVAudioEngineCaptureSource: AudioCaptureSource {

    private let engine = AVAudioEngine()
    private let buffer: RollingAudioBuffer
    private let requestedBufferSize: AVAudioFrameCount
    private let running = OSAllocatedUnfairLock(initialState: false)

    /// Creates a capture source.
    ///
    /// - Parameters:
    ///   - buffer: The destination ring buffer for captured samples.
    ///   - requestedBufferSize: A hint for the tap block size, in frames. The
    ///     system may deliver a different size; callers must not rely on it.
    public init(buffer: RollingAudioBuffer, requestedBufferSize: AVAudioFrameCount = 256) {
        self.buffer = buffer
        self.requestedBufferSize = requestedBufferSize
    }

    public var isRunning: Bool { running.withLock { $0 } }

    /// Starts capture by installing the input tap and starting the engine.
    ///
    /// - Throws: An `AVAudioEngine` error if the engine fails to start.
    public func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let ring = buffer
        input.installTap(onBus: 0, bufferSize: requestedBufferSize, format: format) {
            pcmBuffer, when in
            guard let channelData = pcmBuffer.floatChannelData else { return }
            let frameCount = Int(pcmBuffer.frameLength)
            guard frameCount > 0 else { return }
            let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
            ring.write(samples, hostTime: when.hostTime)
        }
        engine.prepare()
        try engine.start()
        running.withLock { $0 = true }
    }

    /// Stops capture and removes the input tap.
    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running.withLock { $0 = false }
    }

    /// A snapshot of the current capture environment for diagnostics.
    ///
    /// - Returns: Metadata describing the input device and its native format.
    public func currentMetadata() -> AudioMetadata {
        let format = engine.inputNode.inputFormat(forBus: 0)
        return AudioMetadata(
            inputDevice: AVCaptureDevice.default(for: .audio)?.localizedName ?? "Unknown",
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            bitDepth: 32,
            captureTimestamp: Date()
        )
    }
}
