import Foundation

/// Executes an Apple Shortcut by name (`TRD` FR-CE-002, `API_REFERENCE` §5).
///
/// Runs `shortcuts run "<target>"` via the `/usr/bin/shortcuts` CLI and waits
/// for it to exit. Stateless.
///
/// - Note: live execution requires an existing shortcut and a user session, so
///   it is exercised via integration testing rather than CI; the unit test
///   covers only the handled command type.
public struct ShortcutsProvider: CommandProvider {

    /// The path to the Shortcuts command-line tool.
    private static let shortcutsToolPath = "/usr/bin/shortcuts"

    /// Creates a Shortcuts provider.
    public init() {}

    public var commandType: CommandType { .shortcut }

    public func execute(_ command: Command) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.shortcutsToolPath)
        process.arguments = ["run", command.target]
        return ProcessExecution.run(process, commandID: command.id)
    }
}
