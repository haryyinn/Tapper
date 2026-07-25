import Calibration
import Commands

/// Validates configuration objects before writing and after loading
/// (`DATA_MODELS` §13.8: "Validation shall occur both before writing and
/// immediately after loading"; §13.10; §14.8 relationship validation).
///
/// Stateless and deterministic; performs no I/O.
public enum ConfigurationValidator {

    /// Validates a set of command bindings (`DATA_MODELS` §13.10 — unique
    /// interaction zones, valid commands, supported command types).
    ///
    /// - Parameter stored: The bindings to validate.
    /// - Throws: ``ConfigurationError`` describing the first failure found.
    public static func validate(_ stored: PersistedCommandBindings) throws {
        guard SchemaVersion.isSupported(stored.schemaVersion) else {
            throw ConfigurationError.migrationRequired(storedVersion: stored.schemaVersion)
        }
        var seenZones: Set<InteractionZone> = []
        for binding in stored.bindings {
            guard InteractionZone.calibratable.contains(binding.zone) else {
                throw ConfigurationError.unbindableZone(binding.zone.rawValue)
            }
            guard seenZones.insert(binding.zone).inserted else {
                throw ConfigurationError.duplicateZoneBinding(binding.zone.rawValue)
            }
            try validate(binding.command)
        }
    }

    /// Validates a single command (`DATA_MODELS` §12.10).
    ///
    /// - Parameter command: The command to validate.
    /// - Throws: ``ConfigurationError/invalidCommand(_:)`` if invalid.
    public static func validate(_ command: Command) throws {
        do {
            try command.validate()
        } catch let error as CommandValidationError {
            throw ConfigurationError.invalidCommand(String(describing: error))
        }
    }

    /// Validates a calibration profile for persistence (`DATA_MODELS` §13.10 —
    /// all required zones present, valid statistical models; §14.8 — statistical
    /// dimensions match the feature vector).
    ///
    /// - Parameter profile: The profile to validate.
    /// - Throws: ``ConfigurationError`` describing the first failure found.
    public static func validate(_ profile: CalibrationProfile) throws {
        guard !profile.deviceIdentifier.isEmpty else {
            throw ConfigurationError.corruptedData("calibration profile has no device identifier")
        }
        guard !profile.algorithmVersion.isEmpty else {
            throw ConfigurationError.corruptedData("calibration profile has no algorithm version")
        }
        for zone in InteractionZone.calibratable {
            guard let zoneProfile = profile.profile(for: zone) else {
                throw ConfigurationError.corruptedData(
                    "calibration profile is missing zone \(zone.rawValue)")
            }
            try validate(zoneProfile)
        }
    }

    /// Validates one zone profile's statistical dimensions and finiteness.
    private static func validate(_ zoneProfile: ZoneProfile) throws {
        let dimension = zoneProfile.meanVector.values.count
        guard dimension > 0 else {
            throw ConfigurationError.corruptedData(
                "zone \(zoneProfile.zone.rawValue) has an empty mean vector")
        }
        guard zoneProfile.covarianceMatrix.dimension == dimension,
            zoneProfile.inverseCovarianceMatrix.dimension == dimension,
            zoneProfile.covarianceMatrix.values.allSatisfy({ $0.count == dimension }),
            zoneProfile.inverseCovarianceMatrix.values.allSatisfy({ $0.count == dimension })
        else {
            throw ConfigurationError.corruptedData(
                "zone \(zoneProfile.zone.rawValue) has mismatched matrix dimensions")
        }
        let allValues =
            zoneProfile.meanVector.values
            + zoneProfile.covarianceMatrix.values.flatMap { $0 }
            + zoneProfile.inverseCovarianceMatrix.values.flatMap { $0 }
            + [zoneProfile.threshold.acceptanceThreshold, zoneProfile.threshold.ambiguityMargin]
        guard allValues.allSatisfy(\.isFinite) else {
            throw ConfigurationError.corruptedData(
                "zone \(zoneProfile.zone.rawValue) contains non-finite statistical values")
        }
    }
}
