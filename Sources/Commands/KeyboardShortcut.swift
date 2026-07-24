import CoreGraphics

/// A parsed keyboard shortcut: a virtual key code plus modifier flags.
///
/// The result of ``KeyboardShortcutParser``; consumed by
/// ``KeyboardShortcutProvider`` to synthesize CGEvents. Kept separate from event
/// generation so parsing is independently testable.
public struct KeyboardShortcut: Sendable, Equatable {

    /// The virtual key code (US ANSI layout).
    public let keyCode: CGKeyCode

    /// The modifier flags (command, shift, option, control).
    public let modifiers: CGEventFlags

    /// Creates a keyboard shortcut.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual key code.
    ///   - modifiers: The modifier flags.
    public init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}
