/// A source of captured microphone audio.
///
/// This abstraction decouples the acquisition flow from the concrete capture
/// mechanism so it can be exercised with a substitute source in tests, where a
/// live microphone is unavailable. The production implementation is backed by
/// `AVAudioEngine`; tests provide their own conforming double.
///
/// A source delivers samples into a ``RollingAudioBuffer`` supplied at
/// construction time. The abstraction itself makes no assumption about the size
/// or cadence of delivered sample blocks. The delivery destination — the ring
/// buffer — is itself `Sendable` and thread-safe; the source object is used from
/// the controlling thread, so it need not be `Sendable`.
public protocol AudioCaptureSource: AnyObject {

    /// Whether capture is currently active.
    var isRunning: Bool { get }

    /// Starts delivering captured samples into the destination buffer.
    ///
    /// - Throws: An error if capture cannot be started.
    func start() throws

    /// Stops delivering captured samples.
    func stop()
}
