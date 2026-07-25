import Calibration

/// The complete set of persistent resources for one application instance
/// (`DATA_MODELS` §13.7).
///
/// Serves as the root object for loading application state, giving a consistent
/// view of the calibration profile, command bindings, and preferences. Only one
/// active manifest exists at a time, and it is immutable once assembled.
///
/// - Note: §13.7 defines all three members as required, so a manifest exists
///   only for a fully configured installation. Before calibration completes
///   there is no profile and therefore no manifest — recognition must not run
///   without one (`ALGORITHM` §16.19). Use ``ConfigurationStore/loadManifest()``
///   to obtain it.
public struct PersistenceManifest: Sendable, Equatable {

    /// The active calibration profile.
    public let calibrationProfile: CalibrationProfile

    /// The stored zone→command bindings.
    public let commandBindings: PersistedCommandBindings

    /// The stored user preferences.
    public let userPreferences: UserPreferences

    /// Creates a persistence manifest.
    public init(
        calibrationProfile: CalibrationProfile,
        commandBindings: PersistedCommandBindings,
        userPreferences: UserPreferences
    ) {
        self.calibrationProfile = calibrationProfile
        self.commandBindings = commandBindings
        self.userPreferences = userPreferences
    }
}
