import Foundation

/// Executes an AppleScript (`TRD` FR-CE-003, `API_REFERENCE` §5).
///
/// Compiles and runs `command.target` as AppleScript source via `NSAppleScript`.
/// Stateless.
///
/// - Important: `NSAppleScript` should be executed on the main thread; the
///   runtime layer is responsible for dispatching accordingly. Scripts that
///   target other applications additionally require Automation (Apple Events)
///   permission, whose absence surfaces here as a script error.
public struct AppleScriptProvider: CommandProvider {

    /// Creates an AppleScript provider.
    public init() {}

    public var commandType: CommandType { .appleScript }

    public func execute(_ command: Command) -> CommandResult {
        guard let script = NSAppleScript(source: command.target) else {
            return .failure(
                commandID: command.id, at: Date(),
                error: .scriptError("could not create script from source"))
        }
        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message =
                (errorInfo[NSAppleScript.errorMessage] as? String) ?? String(describing: errorInfo)
            return .failure(commandID: command.id, at: Date(), error: .scriptError(message))
        }
        return .success(commandID: command.id, at: Date())
    }
}
