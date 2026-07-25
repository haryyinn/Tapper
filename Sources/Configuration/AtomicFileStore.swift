import Foundation

/// Reads and writes files such that a partially written file is never visible
/// (`ALGORITHM` §26.12, `DATA_MODELS` §13.11).
///
/// Writing follows the documented algorithm exactly:
/// 1. serialize into a temporary file in the **destination directory** (same
///    volume, so the replacement is atomic),
/// 2. flush and synchronize the temporary file to disk,
/// 3. atomically replace the destination.
///
/// An existing valid file is never overwritten until the replacement has been
/// fully written; if any step fails the temporary file is discarded and the
/// existing file is left untouched.
/// - Note: not `Sendable`, because it holds a `FileManager`. Configuration I/O
///   runs on the main thread (`ARCHITECTURE` §7), so the store is used from a
///   single thread rather than shared across concurrency domains.
public struct AtomicFileStore {

    /// The directory holding the configuration files.
    public let directory: URL

    private let fileManager: FileManager

    /// Creates a file store rooted at a directory.
    ///
    /// - Parameters:
    ///   - directory: The base directory (injectable for testing).
    ///   - fileManager: The file manager to use.
    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    /// The default configuration directory:
    /// `~/Library/Application Support/Tapper`.
    ///
    /// - Parameter fileManager: The file manager to query.
    /// - Returns: The directory URL, or `nil` if Application Support is
    ///   unavailable.
    public static func defaultDirectory(fileManager: FileManager = .default) -> URL? {
        guard
            let base = try? fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                create: false)
        else { return nil }
        return base.appendingPathComponent("Tapper", isDirectory: true)
    }

    /// The URL of a named file within the store.
    ///
    /// - Parameter fileName: The file name, including extension.
    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Whether a file exists in the store.
    ///
    /// - Parameter fileName: The file name to check.
    public func fileExists(_ fileName: String) -> Bool {
        fileManager.fileExists(atPath: url(for: fileName).path)
    }

    /// Reads a file's contents.
    ///
    /// - Parameter fileName: The file name to read.
    /// - Returns: The file contents.
    /// - Throws: ``ConfigurationError/storageFailure(_:)`` if the read fails.
    public func read(_ fileName: String) throws -> Data {
        do {
            return try Data(contentsOf: url(for: fileName))
        } catch {
            throw ConfigurationError.storageFailure(String(describing: error))
        }
    }

    /// Atomically writes data to a file, never leaving partial data behind.
    ///
    /// - Parameters:
    ///   - data: The bytes to write.
    ///   - fileName: The destination file name.
    /// - Throws: ``ConfigurationError/storageFailure(_:)`` if the write fails. On
    ///   failure any existing file is left unchanged.
    public func write(_ data: Data, to fileName: String) throws {
        let destination = url(for: fileName)
        do {
            try createDirectoryIfNeeded()
            let temporary = directory.appendingPathComponent(
                ".\(fileName).\(UUID().uuidString).tmp", isDirectory: false)
            try writeAndSynchronize(data, to: temporary)
            do {
                try replace(destination, with: temporary)
            } catch {
                try? fileManager.removeItem(at: temporary)
                throw error
            }
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.storageFailure(String(describing: error))
        }
    }

    /// Deletes a file if it exists.
    ///
    /// - Parameter fileName: The file name to delete.
    /// - Throws: ``ConfigurationError/storageFailure(_:)`` if deletion fails.
    public func delete(_ fileName: String) throws {
        let target = url(for: fileName)
        guard fileManager.fileExists(atPath: target.path) else { return }
        do {
            try fileManager.removeItem(at: target)
        } catch {
            throw ConfigurationError.storageFailure(String(describing: error))
        }
    }

    // MARK: Private

    private func createDirectoryIfNeeded() throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Writes the temporary file and forces it to disk before it is published.
    private func writeAndSynchronize(_ data: Data, to temporary: URL) throws {
        try data.write(to: temporary, options: .atomic)
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    /// Atomically publishes the temporary file at the destination.
    ///
    /// `replaceItemAt` performs an atomic exchange when both files are on the
    /// same volume; when no destination exists yet a move is already atomic.
    private func replace(_ destination: URL, with temporary: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
