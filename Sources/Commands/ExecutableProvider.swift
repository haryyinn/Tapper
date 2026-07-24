import Foundation

/// Executes a local executable (`TRD` FR-CE-005, `API_REFERENCE` §5).
///
/// Runs the executable at `command.target` (an absolute path) and waits for it
/// to exit to capture its status. Version 1 passes no arguments; ordered
/// arguments, if needed later, will extend the command model rather than
/// overload `parameters`. Standard output and error are inherited. Stateless.
public struct ExecutableProvider: CommandProvider {

    /// Creates an executable provider.
    public init() {}

    public var commandType: CommandType { .application }

    public func execute(_ command: Command) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.target)
        return ProcessExecution.run(process, commandID: command.id)
    }
}
