import Foundation

/// The persistent statistical model produced by calibration
/// (`DATA_MODELS` §7.6).
///
/// Immutable and self-contained: it holds every zone profile plus the global
/// normalization transform and the configuration (including λ) needed for
/// runtime recognition (§7.6: "provide runtime configuration for recognition").
/// A profile is never adapted in place — recalibration generates a completely
/// new profile.
///
/// - Note: the canonical §7.6 struct does not yet list the `normalization` and
///   `configuration` fields, and its `metadata.averageQuality` depends on the
///   Tap Quality subsystem (§20). See backlog BL-9 for the documentation
///   reconciliation; no quality value is synthesized here.
public struct CalibrationProfile: Sendable, Equatable, Codable {

    /// Unique profile identifier.
    public let id: UUID

    /// The algorithm version this profile was generated for.
    public let algorithmVersion: String

    /// A device fingerprint (`DATA_MODELS` §7.6).
    public let deviceIdentifier: String

    /// Creation timestamp.
    public let createdAt: Date

    /// The calibrated zone profiles.
    public let zones: [ZoneProfile]

    /// The global normalization transform applied at runtime before distance
    /// computation.
    public let normalization: NormalizationParameters

    /// The configuration used to generate this profile (regularization λ,
    /// thresholds, ambiguity margin).
    public let configuration: CalibrationConfiguration

    /// Creates a calibration profile.
    public init(
        id: UUID,
        algorithmVersion: String,
        deviceIdentifier: String,
        createdAt: Date,
        zones: [ZoneProfile],
        normalization: NormalizationParameters,
        configuration: CalibrationConfiguration
    ) {
        self.id = id
        self.algorithmVersion = algorithmVersion
        self.deviceIdentifier = deviceIdentifier
        self.createdAt = createdAt
        self.zones = zones
        self.normalization = normalization
        self.configuration = configuration
    }

    /// The profile for a given zone, if calibrated.
    ///
    /// - Parameter zone: The zone to look up.
    /// - Returns: The matching ``ZoneProfile``, or `nil`.
    public func profile(for zone: InteractionZone) -> ZoneProfile? {
        zones.first { $0.zone == zone }
    }
}
