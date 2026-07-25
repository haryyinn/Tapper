import Calibration
import Commands
import CryptoKit
import Foundation

/// The result of loading a configuration object that supports defaults.
///
/// Distinguishes a clean load from a recovery so the application can inform the
/// user rather than silently discarding their settings (`TRD` §8,
/// `ARCHITECTURE` §11: corrupt configuration → restore defaults).
public enum ConfigurationLoad<Value: Sendable>: Sendable, Equatable
where Value: Equatable {

    /// A stored object was loaded and validated successfully.
    case loaded(Value)

    /// No stored object existed; defaults are in use.
    case defaultsUsedNoStoredData(Value)

    /// Stored data was unusable; defaults were restored. The reason is
    /// reported so it can be surfaced and logged.
    case defaultsRestoredAfterFailure(Value, ConfigurationError)

    /// The loaded or default value.
    public var value: Value {
        switch self {
        case .loaded(let value),
            .defaultsUsedNoStoredData(let value),
            .defaultsRestoredAfterFailure(let value, _):
            return value
        }
    }
}

/// Loads and persists user preferences, command bindings, and the calibration
/// profile (`ARCHITECTURE` §4.7, `DATA_MODELS` §13).
///
/// All objects are stored as JSON (UTF-8, ISO-8601 dates, `Double` precision) in
/// a local directory and written atomically. Validation runs before writing and
/// immediately after loading (`DATA_MODELS` §13.8); objects failing validation
/// are never written and never loaded.
///
/// Recovery differs by object, following the documentation:
/// - preferences and bindings fall back to defaults when unusable (`TRD` §8),
/// - a calibration profile does **not**, since defaults are meaningless for
///   statistics; the failure is reported so the user can recalibrate
///   (`ALGORITHM` §16.19, `ARCHITECTURE` §11).
public struct ConfigurationStore {

    /// File names within the configuration directory.
    public enum FileName {
        public static let preferences = "preferences.json"
        public static let commandBindings = "command-bindings.json"
        public static let calibrationProfile = "calibration-profile.json"
    }

    private let store: AtomicFileStore

    /// Creates a configuration store.
    ///
    /// - Parameter store: The atomic file store providing the directory.
    public init(store: AtomicFileStore) {
        self.store = store
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: Preferences

    /// Saves user preferences atomically.
    ///
    /// - Parameter preferences: The preferences to persist.
    /// - Throws: ``ConfigurationError`` if encoding or writing fails.
    public func save(_ preferences: UserPreferences) throws {
        let data = try encode(StoredPreferences(preferences: preferences))
        try store.write(data, to: FileName.preferences)
    }

    /// Loads user preferences, restoring defaults if none exist or the stored
    /// data is unusable.
    public func loadPreferences() -> ConfigurationLoad<UserPreferences> {
        guard store.fileExists(FileName.preferences) else {
            return .defaultsUsedNoStoredData(.defaults)
        }
        do {
            let data = try store.read(FileName.preferences)
            let stored = try decode(StoredPreferences.self, from: data)
            guard SchemaVersion.isSupported(stored.schemaVersion) else {
                throw ConfigurationError.migrationRequired(storedVersion: stored.schemaVersion)
            }
            return .loaded(stored.preferences)
        } catch let error as ConfigurationError {
            return .defaultsRestoredAfterFailure(.defaults, error)
        } catch {
            return .defaultsRestoredAfterFailure(
                .defaults, .corruptedData(String(describing: error)))
        }
    }

    // MARK: Command bindings

    /// Validates and atomically saves command bindings.
    ///
    /// - Parameter bindings: The bindings to persist.
    /// - Throws: ``ConfigurationError`` if validation, encoding, or writing fails.
    ///   Nothing is written when validation fails.
    public func save(_ bindings: PersistedCommandBindings) throws {
        try ConfigurationValidator.validate(bindings)
        let data = try encode(bindings)
        try store.write(data, to: FileName.commandBindings)
    }

    /// Loads command bindings, restoring defaults if none exist or the stored
    /// data is unusable or invalid.
    public func loadCommandBindings() -> ConfigurationLoad<PersistedCommandBindings> {
        guard store.fileExists(FileName.commandBindings) else {
            return .defaultsUsedNoStoredData(.defaults)
        }
        do {
            let data = try store.read(FileName.commandBindings)
            let stored = try decode(PersistedCommandBindings.self, from: data)
            try ConfigurationValidator.validate(stored)
            return .loaded(stored)
        } catch let error as ConfigurationError {
            return .defaultsRestoredAfterFailure(.defaults, error)
        } catch {
            return .defaultsRestoredAfterFailure(
                .defaults, .corruptedData(String(describing: error)))
        }
    }

    // MARK: Calibration profile

    /// Validates and atomically saves the calibration profile with an integrity
    /// checksum (`DATA_MODELS` §13.4).
    ///
    /// - Parameter profile: The profile to persist.
    /// - Throws: ``ConfigurationError`` if validation, encoding, or writing fails.
    public func save(_ profile: CalibrationProfile) throws {
        try ConfigurationValidator.validate(profile)
        let profileData = try encode(profile)
        let stored = PersistedCalibrationProfile(
            schemaVersion: SchemaVersion.current,
            profile: profile,
            checksum: Self.checksum(of: profileData)
        )
        try store.write(try encode(stored), to: FileName.calibrationProfile)
    }

    /// Loads the calibration profile.
    ///
    /// Unlike preferences and bindings, there is no default to fall back to: a
    /// missing or unusable profile means recognition cannot start and the user
    /// must recalibrate.
    ///
    /// - Returns: The validated profile, or `nil` if none is stored.
    /// - Throws: ``ConfigurationError`` if the stored profile is corrupt, fails
    ///   its integrity check, is an unsupported version, or fails validation.
    public func loadCalibrationProfile() throws -> CalibrationProfile? {
        guard store.fileExists(FileName.calibrationProfile) else { return nil }
        let data = try store.read(FileName.calibrationProfile)
        let stored: PersistedCalibrationProfile
        do {
            stored = try decode(PersistedCalibrationProfile.self, from: data)
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.corruptedData(String(describing: error))
        }
        guard SchemaVersion.isSupported(stored.schemaVersion) else {
            throw ConfigurationError.migrationRequired(storedVersion: stored.schemaVersion)
        }
        let recomputed = Self.checksum(of: try encode(stored.profile))
        guard recomputed == stored.checksum else {
            throw ConfigurationError.integrityCheckFailed
        }
        try ConfigurationValidator.validate(stored.profile)
        return stored.profile
    }

    // MARK: Restore defaults

    /// Restores default preferences and bindings (`TRD` FR-CM-004).
    ///
    /// The calibration profile is left untouched: it is user-generated
    /// statistical data with no meaningful default, and preference changes must
    /// not invalidate calibration (`DATA_MODELS` §13.6).
    ///
    /// - Throws: ``ConfigurationError`` if writing fails.
    public func restoreDefaults() throws {
        try save(UserPreferences.defaults)
        try save(PersistedCommandBindings.defaults)
    }

    // MARK: Private

    private func encode<Value: Encodable>(_ value: Value) throws -> Data {
        do {
            return try Self.makeEncoder().encode(value)
        } catch {
            throw ConfigurationError.storageFailure(String(describing: error))
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try Self.makeDecoder().decode(type, from: data)
        } catch {
            throw ConfigurationError.corruptedData(String(describing: error))
        }
    }

    /// The SHA-256 hex digest used for calibration-profile integrity
    /// verification (`DATA_MODELS` §13.4, §14.10).
    static func checksum(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// The stored form of ``UserPreferences``, carrying its schema version
/// (`DATA_MODELS` §13.3).
struct StoredPreferences: Codable, Equatable {
    let schemaVersion: String
    let preferences: UserPreferences

    init(schemaVersion: String = SchemaVersion.current, preferences: UserPreferences) {
        self.schemaVersion = schemaVersion
        self.preferences = preferences
    }
}

/// The serialized form of the active calibration profile with an integrity
/// checksum (`DATA_MODELS` §13.4).
public struct PersistedCalibrationProfile: Sendable, Equatable, Codable {

    /// The schema version of this stored object.
    public let schemaVersion: String

    /// The stored calibration profile.
    public let profile: CalibrationProfile

    /// The integrity checksum of the serialized profile.
    public let checksum: String

    /// Creates a persisted calibration profile.
    public init(schemaVersion: String, profile: CalibrationProfile, checksum: String) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.checksum = checksum
    }
}
