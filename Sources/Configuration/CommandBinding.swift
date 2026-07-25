import Calibration
import Commands

/// Associates an interaction zone with the command to execute when that zone is
/// recognized (`DATA_MODELS` §12.4).
///
/// Owned by the Configuration system: it defines *what should happen*, while the
/// Commands subsystem performs execution and the recognition engine decides
/// *what was tapped*. Immutable; every calibrated zone has at most one active
/// binding.
public struct CommandBinding: Sendable, Equatable, Codable {

    /// The bound interaction zone.
    public let zone: InteractionZone

    /// The command to execute for that zone.
    public let command: Command

    /// Creates a command binding.
    ///
    /// - Parameters:
    ///   - zone: The interaction zone.
    ///   - command: The command to execute.
    public init(zone: InteractionZone, command: Command) {
        self.zone = zone
        self.command = command
    }
}

/// The persisted set of zone→command mappings (`DATA_MODELS` §13.5).
///
/// Carries a schema version (§13.3) so stored bindings can be version-validated
/// on load. Immutable once loaded.
public struct PersistedCommandBindings: Sendable, Equatable, Codable {

    /// The schema version of this stored object.
    public let schemaVersion: String

    /// The stored bindings.
    public let bindings: [CommandBinding]

    /// Creates a persisted binding set.
    ///
    /// - Parameters:
    ///   - schemaVersion: The schema version. Defaults to
    ///     ``SchemaVersion/current``.
    ///   - bindings: The bindings to store.
    public init(schemaVersion: String = SchemaVersion.current, bindings: [CommandBinding]) {
        self.schemaVersion = schemaVersion
        self.bindings = bindings
    }

    /// The default (empty) binding set restored on first launch or after
    /// corruption (`TRD` FR-CM-004, §8).
    public static let defaults = PersistedCommandBindings(bindings: [])

    /// The binding for a zone, if one exists.
    ///
    /// - Parameter zone: The zone to look up.
    /// - Returns: The matching binding, or `nil`.
    public func binding(for zone: InteractionZone) -> CommandBinding? {
        bindings.first { $0.zone == zone }
    }
}
