import Foundation

/// Dispatches a command to the provider registered for its type.
///
/// The executor is a **simple dispatcher**: it routes by ``CommandType`` and
/// returns the provider's ``CommandResult``. It performs no retries, provider
/// chaining, fallback, or heuristics. A command whose type has no registered
/// provider yields a failed result. Admission control (validation) is performed
/// at the queue boundary (`DATA_MODELS` §12.10), not here.
///
/// The executor is decoupled from recognition; it executes only the commands it
/// is given. Producing a command solely for successful classifications, and
/// gating on `.success`, is the responsibility of the runtime layer.
public struct CommandExecutor: Sendable {

    private let providers: [CommandType: any CommandProvider]

    /// Creates an executor from a set of providers.
    ///
    /// - Parameter providers: The providers to register. If two providers claim
    ///   the same type, the last one wins.
    public init(providers: [any CommandProvider]) {
        self.providers = Dictionary(
            providers.map { ($0.commandType, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// The command types with a registered provider.
    public var supportedTypes: Set<CommandType> { Set(providers.keys) }

    /// Dispatches a command to its provider.
    ///
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - date: The completion timestamp used if no provider is registered.
    /// - Returns: The provider's result, or a failed result of type
    ///   ``CommandExecutionError/unsupportedType(_:)`` when no provider matches.
    public func execute(_ command: Command, at date: Date) -> CommandResult {
        guard let provider = providers[command.type] else {
            return .failure(commandID: command.id, at: date, error: .unsupportedType(command.type))
        }
        return provider.execute(command)
    }
}
