import Foundation
import os

/// A fixed-capacity, thread-safe rolling buffer of raw PCM samples.
///
/// Incoming microphone samples are appended continuously; once the buffer is
/// full, the oldest samples are overwritten. This provides the constant-memory,
/// O(1)-per-sample rolling storage required by `ALGORITHM` §7.4 / §25.4, with no
/// heap allocation on the write path.
///
/// The buffer is the authoritative store of captured audio. Downstream stages
/// (DSP, Phase 2) read the most recent samples to construct analysis windows;
/// the size of the audio callback that produced the samples is irrelevant and is
/// never assumed to be fixed.
///
/// ## Threading
/// `write(_:hostTime:)` is safe to call from the real-time audio thread. It
/// performs no allocation and holds a lightweight unfair lock only for the copy.
/// Reads occur on other threads. This deliberately simple lock-based design
/// satisfies the documented requirements and can be replaced with a dedicated
/// lock-free implementation if profiling later shows synchronization to be a
/// bottleneck.
public final class RollingAudioBuffer: Sendable {

    /// Default ring capacity in samples.
    ///
    /// This is an implementation default, **not** an algorithmic constant. It is
    /// sized to comfortably exceed the 2048-sample analysis window (`ALGORITHM`
    /// §27.4) with headroom for window overlap and consumer lag.
    public static let defaultCapacity = 16_384

    /// The fixed capacity of the ring, in samples.
    public let capacity: Int

    /// Mutable state guarded by the lock. `storage` is allocated once at
    /// initialization and never resized, so writes never allocate.
    private struct State {
        var storage: [Float]
        var writeIndex: Int
        var totalWritten: Int
        var lastWriteHostTime: UInt64
    }

    private let lock: OSAllocatedUnfairLock<State>

    /// Creates a rolling buffer.
    ///
    /// - Parameter capacity: Ring capacity in samples. Must be positive.
    ///   Defaults to ``defaultCapacity``.
    public init(capacity: Int = defaultCapacity) {
        precondition(capacity > 0, "RollingAudioBuffer capacity must be positive")
        self.capacity = capacity
        self.lock = OSAllocatedUnfairLock(
            initialState: State(
                storage: [Float](repeating: 0, count: capacity),
                writeIndex: 0,
                totalWritten: 0,
                lastWriteHostTime: 0
            )
        )
    }

    /// Appends samples to the ring, overwriting the oldest data once full.
    ///
    /// Safe to call from the real-time audio thread; performs no allocation.
    ///
    /// - Parameters:
    ///   - samples: The samples to append, in chronological order.
    ///   - hostTime: The mach host time of this write, used for precise timing.
    public func write(_ samples: UnsafeBufferPointer<Float>, hostTime: UInt64) {
        guard samples.count > 0 else { return }
        // `withLockUnchecked` is required because `samples` is a non-Sendable
        // `UnsafeBufferPointer`; the pointer is only read within the critical
        // section and never escapes, so the access is safe.
        lock.withLockUnchecked { state in
            var index = state.writeIndex
            for sample in samples {
                state.storage[index] = sample
                index += 1
                if index == capacity { index = 0 }
            }
            state.writeIndex = index
            state.totalWritten += samples.count
            state.lastWriteHostTime = hostTime
        }
    }

    /// Convenience overload appending an array of samples.
    ///
    /// - Parameters:
    ///   - samples: The samples to append, in chronological order.
    ///   - hostTime: The mach host time of this write.
    public func write(_ samples: [Float], hostTime: UInt64) {
        samples.withUnsafeBufferPointer { write($0, hostTime: hostTime) }
    }

    /// The number of samples currently retained (at most ``capacity``).
    public var availableSampleCount: Int {
        lock.withLock { min($0.totalWritten, capacity) }
    }

    /// The total number of samples ever written, including overwritten samples.
    public var totalSamplesWritten: Int {
        lock.withLock { $0.totalWritten }
    }

    /// The mach host time recorded for the most recent write, or `0` if none.
    public var lastWriteHostTime: UInt64 {
        lock.withLock { $0.lastWriteHostTime }
    }

    /// Returns up to `count` of the most recent samples, in chronological order.
    ///
    /// If fewer than `count` samples are available, all available samples are
    /// returned. The returned array is a snapshot copy and is safe to use off
    /// the audio thread.
    ///
    /// - Parameter count: The maximum number of recent samples to return.
    /// - Returns: The most recent samples, oldest first.
    public func latestSamples(_ count: Int) -> [Float] {
        guard count > 0 else { return [] }
        return lock.withLock { state in
            let available = min(count, min(state.totalWritten, capacity))
            guard available > 0 else { return [] }
            var result = [Float](repeating: 0, count: available)
            var index = (state.writeIndex - available + capacity) % capacity
            for offset in 0..<available {
                result[offset] = state.storage[index]
                index += 1
                if index == capacity { index = 0 }
            }
            return result
        }
    }

    /// Clears all retained samples and resets counters.
    public func reset() {
        lock.withLock { state in
            for index in state.storage.indices { state.storage[index] = 0 }
            state.writeIndex = 0
            state.totalWritten = 0
            state.lastWriteHostTime = 0
        }
    }
}
