import Audio
import Features
import Foundation
import os

/// Drives the recognition worker: pulls analysis frames from the audio ring
/// buffer and feeds them to ``RecognitionRuntime`` (`ARCHITECTURE` §7).
///
/// This is the thread-separation boundary. The audio callback only captures and
/// writes to the ring (`Audio`); every recognition step — detection, feature
/// extraction, classification, execution dispatch — runs here on a dedicated
/// serial queue, never on the audio thread.
///
/// The engine owns **sequencing and scheduling only**. It contains no
/// recognition logic: each frame is handed to `RecognitionRuntime`, which
/// delegates to the owning subsystems.
public final class RecognitionEngine: @unchecked Sendable {

    /// How the engine reports each processed frame, for observation and
    /// validation tooling.
    public typealias FrameObserver = @Sendable (FrameOutcome, Date) -> Void

    private let buffer: RollingAudioBuffer
    private let extractor: AnalysisFrameExtractor
    private let queue: DispatchQueue
    private let pollInterval: TimeInterval

    /// Guarded state. `RecognitionRuntime` is not `Sendable` (it holds a vDSP
    /// FFT plan), so the state is guarded with unchecked locking: it is only
    /// ever touched inside the lock, on the worker queue or a caller's thread.
    private let state: OSAllocatedUnfairLock<State>

    private struct State {
        var runtime: RecognitionRuntime
        var isRunning: Bool
        var observer: FrameObserver?
    }

    /// Creates a recognition engine.
    ///
    /// - Parameters:
    ///   - runtime: The per-frame orchestrator.
    ///   - buffer: The ring buffer written by the audio callback.
    ///   - extractor: The analysis-frame windowing configuration.
    ///   - pollInterval: How often the worker checks for new samples. Defaults
    ///     to one hop (20 ms at the Version 1 settings).
    public init(
        runtime: RecognitionRuntime,
        buffer: RollingAudioBuffer,
        extractor: AnalysisFrameExtractor = .v1,
        pollInterval: TimeInterval = 0.020
    ) {
        self.buffer = buffer
        self.extractor = extractor
        self.pollInterval = pollInterval
        self.queue = DispatchQueue(label: "com.tapper.recognition-worker", qos: .userInitiated)
        self.state = OSAllocatedUnfairLock(
            uncheckedState: State(runtime: runtime, isRunning: false, observer: nil))
    }

    /// Whether the worker is running.
    public var isRunning: Bool { state.withLockUnchecked { $0.isRunning } }

    /// Sets an observer notified for every processed frame.
    ///
    /// Observation is diagnostic: it cannot alter the outcome.
    ///
    /// - Parameter observer: The observer, or `nil` to remove it.
    public func setFrameObserver(_ observer: FrameObserver?) {
        state.withLockUnchecked { $0.observer = observer }
    }

    /// Sets an observer notified with the feature vector of every validated
    /// candidate, before it is classified.
    ///
    /// Instrumentation for validation tooling that evaluates an alternative
    /// recogniser on exactly the vector production classified (ADR-015). Like
    /// ``setFrameObserver(_:)`` it cannot alter the outcome.
    ///
    /// - Parameter observer: The observer, or `nil` to remove it.
    public func setCandidateObserver(_ observer: (@Sendable (FeatureVector, Date) -> Void)?) {
        state.withLockUnchecked { $0.runtime.candidateObserver = observer }
    }

    /// Starts the recognition worker.
    ///
    /// Audio capture is started by the caller. The first polls read whatever the
    /// ring already holds, so audio captured just before starting contributes to
    /// the ambient noise-floor estimate rather than being discarded.
    public func start() {
        let shouldStart = state.withLockUnchecked { state -> Bool in
            guard !state.isRunning else { return false }
            state.isRunning = true
            return true
        }
        guard shouldStart else { return }
        queue.async { [weak self] in self?.pump() }
    }

    /// Stops the recognition worker. In-flight frames finish; no new frames are
    /// consumed.
    public func stop() {
        state.withLockUnchecked { $0.isRunning = false }
    }

    /// Processes any complete frames currently available, then reschedules.
    private func pump() {
        guard isRunning else { return }
        processAvailableFrames()
        queue.asyncAfter(deadline: .now() + pollInterval) { [weak self] in self?.pump() }
    }

    /// Reads the most recent analysis window and processes it.
    ///
    /// Polling once per hop yields the documented 50% window overlap
    /// (`ALGORITHM` §11.3) at the Version 1 settings.
    private func processAvailableFrames() {
        let available = buffer.availableSampleCount
        guard available >= extractor.frameSize else { return }

        let samples = buffer.latestSamples(extractor.frameSize)
        guard samples.count == extractor.frameSize else { return }
        let frame = samples.map(Double.init)
        let timestamp = Date()

        let outcome = state.withLockUnchecked { state -> FrameOutcome? in
            guard state.isRunning else { return nil }
            return state.runtime.process(frame: frame, at: timestamp)
        }
        guard let outcome else { return }

        let observer = state.withLockUnchecked { $0.observer }
        observer?(outcome, timestamp)
    }

    /// Processes a single supplied frame, bypassing the ring buffer.
    ///
    /// Used by validation tooling that drives frames explicitly.
    ///
    /// - Parameters:
    ///   - frame: The analysis frame.
    ///   - timestamp: The frame timestamp.
    /// - Returns: The outcome.
    @discardableResult
    public func processDirectly(frame: [Double], at timestamp: Date) -> FrameOutcome {
        let outcome = state.withLockUnchecked { $0.runtime.process(frame: frame, at: timestamp) }
        let observer = state.withLockUnchecked { $0.observer }
        observer?(outcome, timestamp)
        return outcome
    }
}
