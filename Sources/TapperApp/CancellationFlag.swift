import Foundation

/// A thread-safe cancellation flag shared between the user interface and a
/// background workflow loop.
///
/// The loop polls this instead of synchronising with the main queue, so a long
/// run can never block or deadlock on the main thread.
final class CancellationFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var cancelled = false

    /// Whether cancellation has been requested.
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Requests cancellation.
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    /// Clears the flag for a new run.
    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
    }
}
