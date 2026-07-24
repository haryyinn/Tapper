import ApplicationServices
import CoreGraphics
import Foundation

/// Executes a keyboard shortcut by synthesizing key events (`TRD` FR-CE-001,
/// `API_REFERENCE` §5).
///
/// Parses `command.target` into a ``KeyboardShortcut`` (via
/// ``KeyboardShortcutParser``), then posts key-down/key-up CGEvents with the
/// modifier flags. Stateless.
///
/// Keyboard injection requires Accessibility permission; if the process is not
/// trusted, execution is aborted with a permission error rather than attempted
/// (`TRD` FR-CE-006). Parsing is separated from event generation so it can be
/// tested without producing any keystroke; the live post is exercised only via
/// integration testing (it has an externally observable side effect).
public struct KeyboardShortcutProvider: CommandProvider {

    /// Creates a keyboard shortcut provider.
    public init() {}

    public var commandType: CommandType { .keyboardShortcut }

    public func execute(_ command: Command) -> CommandResult {
        guard let shortcut = KeyboardShortcutParser.parse(command.target) else {
            return .failure(
                commandID: command.id, at: Date(), error: .invalidTarget(command.target))
        }
        guard AXIsProcessTrusted() else {
            return .failure(commandID: command.id, at: Date(), error: .permissionDenied)
        }
        guard postKeyEvents(for: shortcut) else {
            return .failure(
                commandID: command.id, at: Date(),
                error: .executionFailed("could not create keyboard event"))
        }
        return .success(commandID: command.id, at: Date())
    }

    private func postKeyEvents(for shortcut: KeyboardShortcut) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
            let keyUp = CGEvent(
                keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false)
        else { return false }
        keyDown.flags = shortcut.modifiers
        keyUp.flags = shortcut.modifiers
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
