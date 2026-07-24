import CoreGraphics

/// Parses a keyboard-shortcut string into a ``KeyboardShortcut``.
///
/// Grammar: zero or more modifiers followed by exactly one key, joined by `+`,
/// e.g. `command+shift+c`. Parsing is case-insensitive and pure (no side
/// effects), so it is independently testable without generating any events.
public enum KeyboardShortcutParser {

    /// US ANSI virtual key codes for the supported keys.
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
        "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17,
        "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        "space": 49, "return": 36, "enter": 36, "tab": 48, "escape": 53, "esc": 53, "delete": 51,
    ]

    /// Modifier tokens and their event flags.
    private static let modifierFlags: [String: CGEventFlags] = [
        "command": .maskCommand, "cmd": .maskCommand,
        "shift": .maskShift,
        "option": .maskAlternate, "alt": .maskAlternate, "opt": .maskAlternate,
        "control": .maskControl, "ctrl": .maskControl,
    ]

    /// Parses a shortcut string.
    ///
    /// - Parameter string: A combo string such as `command+shift+c`.
    /// - Returns: The parsed ``KeyboardShortcut``, or `nil` if the key is
    ///   unknown, a modifier is unknown, or no key is present.
    public static func parse(_ string: String) -> KeyboardShortcut? {
        let tokens = string.split(separator: "+").map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        guard let keyToken = tokens.last, let keyCode = keyCodes[keyToken] else { return nil }

        var modifiers: CGEventFlags = []
        for token in tokens.dropLast() {
            guard let flag = modifierFlags[token] else { return nil }
            modifiers.insert(flag)
        }
        return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
    }
}
