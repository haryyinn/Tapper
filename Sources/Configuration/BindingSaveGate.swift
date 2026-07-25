import Commands

/// Enforces the documented confirmation requirement for saving shell-command
/// bindings (`TRD` §9: "User confirmation required before saving destructive
/// shell commands").
///
/// The specification does not define what makes a shell command *destructive*,
/// so no classifier is implemented — inferring destructiveness would be
/// undocumented behavior. Version 1 instead applies the requirement
/// conservatively: **every** `.shellCommand` binding requires explicit user
/// confirmation before it can be saved, which is a superset of the documented
/// rule.
///
/// This is a **save-time** mechanism only. Nothing here runs at execution time,
/// and the Commands subsystem applies no such policy.
public enum BindingSaveGate {

    /// Whether saving a binding requires explicit user confirmation.
    ///
    /// - Parameter binding: The binding about to be saved.
    /// - Returns: `true` for shell-command bindings.
    public static func requiresConfirmation(_ binding: CommandBinding) -> Bool {
        binding.command.type == .shellCommand
    }

    /// Checks that a binding may be saved.
    ///
    /// - Parameters:
    ///   - binding: The binding about to be saved.
    ///   - userConfirmed: Whether the user explicitly confirmed this save.
    /// - Throws: ``ConfigurationError/confirmationRequired`` when confirmation is
    ///   required but was not given.
    public static func checkSaveAllowed(_ binding: CommandBinding, userConfirmed: Bool) throws {
        if requiresConfirmation(binding) && !userConfirmed {
            throw ConfigurationError.confirmationRequired
        }
    }

    /// Checks that a set of bindings may be saved.
    ///
    /// - Parameters:
    ///   - bindings: The bindings about to be saved.
    ///   - userConfirmed: Whether the user explicitly confirmed this save.
    /// - Throws: ``ConfigurationError/confirmationRequired`` if any binding
    ///   requires confirmation that was not given.
    public static func checkSaveAllowed(
        _ bindings: PersistedCommandBindings, userConfirmed: Bool
    ) throws {
        for binding in bindings.bindings {
            try checkSaveAllowed(binding, userConfirmed: userConfirmed)
        }
    }
}
