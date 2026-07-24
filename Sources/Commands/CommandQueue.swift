/// A transient FIFO queue of commands awaiting execution (`DATA_MODELS` §12.5).
///
/// Isolates recognition from execution. Commands are dequeued in first-in,
/// first-out order and each is dequeued exactly once, so no command is executed
/// twice. Enqueuing validates the command (`DATA_MODELS` §12.10) so invalid
/// commands never enter the queue. Transient: never persisted across restarts.
public struct CommandQueue: Sendable, Equatable {

    /// The commands awaiting execution, in order.
    public private(set) var pendingCommands: [Command]

    /// Creates a queue.
    ///
    /// - Parameter pendingCommands: Initial pending commands. Defaults to empty.
    public init(pendingCommands: [Command] = []) {
        self.pendingCommands = pendingCommands
    }

    /// Whether the queue is empty.
    public var isEmpty: Bool { pendingCommands.isEmpty }

    /// Enqueues a command if it is valid.
    ///
    /// - Parameter command: The command to enqueue.
    /// - Returns: `true` if enqueued; `false` if the command failed validation
    ///   and was rejected.
    @discardableResult
    public mutating func enqueue(_ command: Command) -> Bool {
        guard command.isValid else { return false }
        pendingCommands.append(command)
        return true
    }

    /// Removes and returns the next command in FIFO order.
    ///
    /// - Returns: The next command, or `nil` if the queue is empty.
    public mutating func dequeue() -> Command? {
        pendingCommands.isEmpty ? nil : pendingCommands.removeFirst()
    }
}
