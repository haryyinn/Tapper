import Foundation

/// The outcome of an attempted command execution (`DATA_MODELS` §12.6).
///
/// Reflects execution success (distinct from recognition success). Immutable. An
/// `errorMessage` is present only when execution failed.
public struct CommandResult: Sendable, Equatable {

    /// The identifier of the executed command.
    public let commandID: UUID

    /// Whether execution succeeded.
    public let succeeded: Bool

    /// The completion timestamp.
    public let completedAt: Date

    /// A failure description, present only when ``succeeded`` is `false`.
    public let errorMessage: String?

    /// Creates a command result.
    public init(commandID: UUID, succeeded: Bool, completedAt: Date, errorMessage: String?) {
        self.commandID = commandID
        self.succeeded = succeeded
        self.completedAt = completedAt
        self.errorMessage = errorMessage
    }

    /// A successful result.
    ///
    /// - Parameters:
    ///   - commandID: The executed command's identifier.
    ///   - date: The completion timestamp.
    public static func success(commandID: UUID, at date: Date) -> CommandResult {
        CommandResult(commandID: commandID, succeeded: true, completedAt: date, errorMessage: nil)
    }

    /// A failed result carrying a failure description.
    ///
    /// - Parameters:
    ///   - commandID: The executed command's identifier.
    ///   - date: The completion timestamp.
    ///   - error: The execution failure.
    public static func failure(
        commandID: UUID, at date: Date, error: CommandExecutionError
    ) -> CommandResult {
        CommandResult(
            commandID: commandID, succeeded: false, completedAt: date,
            errorMessage: error.description)
    }
}

/// A validation failure for a ``CommandResult`` (`DATA_MODELS` §12.10).
public enum CommandResultValidationError: Error, Equatable {

    /// An error message was present on a successful result.
    case errorMessageOnSuccess
}

extension CommandResult {

    /// Validates the result against `DATA_MODELS` §12.10 (an error message may be
    /// present only when execution failed).
    ///
    /// - Throws: ``CommandResultValidationError`` if the result is invalid.
    public func validate() throws {
        if succeeded && errorMessage != nil {
            throw CommandResultValidationError.errorMessageOnSuccess
        }
    }
}
