/// A stateless executor for a single ``CommandType`` (`DECISIONS` ADR-012).
///
/// A provider maps `Command → execute → CommandResult` and nothing more. It
/// retains no execution history, caches, mutable configuration, or recognition
/// state, and is independent of the recognition engine.
public protocol CommandProvider: Sendable {

    /// The command type this provider handles.
    var commandType: CommandType { get }

    /// Executes the command and returns its outcome.
    ///
    /// Failures are reported as a failed ``CommandResult``; the provider does not
    /// throw.
    ///
    /// - Parameter command: The command to execute.
    /// - Returns: The execution outcome.
    func execute(_ command: Command) -> CommandResult
}
