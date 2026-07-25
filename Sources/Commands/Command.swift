import Foundation

/// A single executable action generated for a successful recognition
/// (`DATA_MODELS` §12.3).
///
/// Every successful recognition maps to exactly one `Command`. Immutable and
/// independent of recognition logic. The meaning of ``target`` depends on
/// ``type``:
/// - ``CommandType/shellCommand``: a shell command line (run via `/bin/sh -c`).
/// - ``CommandType/application``: an absolute path to an executable to run.
/// - ``CommandType/appleScript``: AppleScript source text.
/// - ``CommandType/shortcut``: the name of an Apple Shortcut.
/// - ``CommandType/keyboardShortcut``: a combo string such as `command+shift+c`.
///
/// Version 1 providers do not read ``parameters``; ordered arguments, if needed
/// later, will extend the model rather than overload the dictionary.
public struct Command: Sendable, Equatable, Codable {

    /// Unique command identifier.
    public let id: UUID

    /// The type of executable action.
    public let type: CommandType

    /// The execution target, interpreted according to ``type``.
    public let target: String

    /// Optional execution parameters. Unused by Version 1 providers.
    public let parameters: [String: String]

    /// Creates a command.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a freshly generated `UUID`.
    ///   - type: The type of action.
    ///   - target: The execution target.
    ///   - parameters: Optional parameters. Defaults to empty.
    public init(
        id: UUID = UUID(),
        type: CommandType,
        target: String,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.target = target
        self.parameters = parameters
    }
}

/// A validation failure for a ``Command`` (`DATA_MODELS` §12.10).
public enum CommandValidationError: Error, Equatable {

    /// The target was empty.
    case emptyTarget

    /// A parameter key was empty.
    case emptyParameterKey
}

extension Command {

    /// Validates the command against `DATA_MODELS` §12.10.
    ///
    /// - Throws: ``CommandValidationError`` if the command is invalid.
    public func validate() throws {
        guard !target.isEmpty else { throw CommandValidationError.emptyTarget }
        guard parameters.keys.allSatisfy({ !$0.isEmpty }) else {
            throw CommandValidationError.emptyParameterKey
        }
    }

    /// Whether the command satisfies ``validate()``.
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
}
