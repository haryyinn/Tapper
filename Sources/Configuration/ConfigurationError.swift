/// A failure encountered while validating, saving, or loading configuration
/// (`DATA_MODELS` §14.11).
public enum ConfigurationError: Error, Equatable {

    // MARK: Validation (`DATA_MODELS` §13.10)

    /// Two or more bindings referenced the same interaction zone.
    case duplicateZoneBinding(InteractionZoneIdentifier)

    /// A binding referenced a zone that cannot be bound (for example `unknown`).
    case unbindableZone(InteractionZoneIdentifier)

    /// A binding's command failed validation.
    case invalidCommand(CommandValidationFailure)

    /// Saving a shell-command binding was attempted without explicit user
    /// confirmation (`TRD` §9).
    case confirmationRequired

    // MARK: Loading

    /// The stored data could not be decoded (malformed or truncated).
    case corruptedData(String)

    /// The stored object's integrity check failed (`DATA_MODELS` §14.10).
    case integrityCheckFailed

    /// The stored schema version is not supported; the data must be regenerated
    /// or migrated (`DATA_MODELS` §13.13, §14.9).
    case migrationRequired(storedVersion: String)

    // MARK: Storage

    /// A read or write operation failed.
    case storageFailure(String)
}

/// A stable textual identifier for an interaction zone, used in configuration
/// errors so error values carry no dependency on recognition internals.
public typealias InteractionZoneIdentifier = String

/// A stable textual description of why a command failed validation.
public typealias CommandValidationFailure = String
