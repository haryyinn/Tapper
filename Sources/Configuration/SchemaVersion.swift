/// The schema version stamped on every persisted object
/// (`DATA_MODELS` §13.3, §13.13, §14.9).
///
/// Version 1 writes and accepts exactly ``current``. Objects carrying any other
/// version are rejected with an explicit migration-required outcome rather than
/// being migrated speculatively — no Version 1 → Version 1 transformation exists.
public enum SchemaVersion {

    /// The schema version written by this build.
    public static let current = "1.0"

    /// The schema versions this build can load.
    public static let supported: Set<String> = [current]

    /// Whether a stored schema version can be loaded.
    ///
    /// - Parameter version: The version string read from storage.
    /// - Returns: `true` when the version is supported.
    public static func isSupported(_ version: String) -> Bool {
        supported.contains(version)
    }
}
