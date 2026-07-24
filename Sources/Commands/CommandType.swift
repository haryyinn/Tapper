/// The category of action executed after successful recognition
/// (`DATA_MODELS` §3.16).
///
/// Each case is handled by exactly one execution provider (`DECISIONS` ADR-012),
/// except ``custom``, which has no Version 1 provider and exists for future
/// extensibility.
public enum CommandType: Sendable, Equatable {
    case keyboardShortcut
    case shellCommand
    case appleScript
    case shortcut
    case application
    case custom
}
