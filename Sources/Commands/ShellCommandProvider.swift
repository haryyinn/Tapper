import Foundation

/// Executes a shell command (`TRD` FR-CE-004, `API_REFERENCE` §5).
///
/// Runs `command.target` via `/bin/sh -c`. Standard output and error are
/// inherited and therefore preserved exactly as produced. Stateless.
///
/// - Note: confirmation for destructive shell commands is a save-time policy of
///   the Configuration subsystem (`TRD` §9); this execution provider applies no
///   such policy and infers no notion of "destructive."
public struct ShellCommandProvider: CommandProvider {

    /// Creates a shell command provider.
    public init() {}

    public var commandType: CommandType { .shellCommand }

    public func execute(_ command: Command) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command.target]
        return ProcessExecution.run(process, commandID: command.id)
    }
}
