/// A failure encountered while executing a command.
///
/// Provides consistent error semantics across all providers. Providers surface
/// failures as a ``CommandResult`` whose `errorMessage` is this value's
/// ``description``.
public enum CommandExecutionError: Error, Equatable, CustomStringConvertible {

    /// No provider is registered for the command's type.
    case unsupportedType(CommandType)

    /// The command failed validation before execution.
    case invalidCommand(CommandValidationError)

    /// A required permission (e.g. Accessibility) was not granted.
    case permissionDenied

    /// The command's target could not be interpreted (e.g. an unparseable
    /// keyboard shortcut).
    case invalidTarget(String)

    /// A process could not be launched.
    case processLaunchFailed(String)

    /// A launched process exited with a non-zero status.
    case nonZeroExit(Int32)

    /// A script failed to compile or execute.
    case scriptError(String)

    /// Execution failed for a provider-specific reason.
    case executionFailed(String)

    public var description: String {
        switch self {
        case .unsupportedType(let type):
            return "No provider registered for command type \(type)."
        case .invalidCommand(let error):
            return "Invalid command: \(error)."
        case .permissionDenied:
            return "Permission denied."
        case .invalidTarget(let detail):
            return "Invalid target: \(detail)."
        case .processLaunchFailed(let detail):
            return "Process launch failed: \(detail)."
        case .nonZeroExit(let code):
            return "Process exited with non-zero status \(code)."
        case .scriptError(let detail):
            return "Script error: \(detail)."
        case .executionFailed(let detail):
            return "Execution failed: \(detail)."
        }
    }
}
