import Foundation
import XCTest

@testable import Configuration

final class AtomicFileStoreTests: XCTestCase {

    private var directory: URL!
    private var store: AtomicFileStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-tests-\(UUID().uuidString)", isDirectory: true)
        store = AtomicFileStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func temporaryFileNames() throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".tmp") }
    }

    func testWriteCreatesDirectoryAndFile() throws {
        try store.write(Data("hello".utf8), to: "config.json")
        XCTAssertTrue(store.fileExists("config.json"))
        XCTAssertEqual(try store.read("config.json"), Data("hello".utf8))
    }

    func testReplacementIsExactWhenShrinking() throws {
        try store.write(Data("a-much-longer-original-payload".utf8), to: "config.json")
        try store.write(Data("tiny".utf8), to: "config.json")
        XCTAssertEqual(
            try store.read("config.json"), Data("tiny".utf8),
            "replacement must not leave a tail of the previous contents")
    }

    func testNoTemporaryFilesRemainAfterWrites() throws {
        try store.write(Data("one".utf8), to: "config.json")
        try store.write(Data("two".utf8), to: "config.json")
        XCTAssertEqual(try temporaryFileNames(), [], "no partially-written data may remain")
    }

    func testReadingMissingFileFails() {
        XCTAssertThrowsError(try store.read("absent.json")) { error in
            guard case .storageFailure = error as? ConfigurationError else {
                return XCTFail("expected storageFailure, got \(error)")
            }
        }
    }

    func testFailedWriteLeavesExistingFileIntact() throws {
        try store.write(Data("original".utf8), to: "config.json")
        // Writing into an unwritable location must fail without touching the
        // existing valid file in this store.
        let blocked = AtomicFileStore(directory: URL(fileURLWithPath: "/dev/null/nested"))
        XCTAssertThrowsError(try blocked.write(Data("new".utf8), to: "config.json"))
        XCTAssertEqual(try store.read("config.json"), Data("original".utf8))
    }

    func testDeleteRemovesFileAndIsIdempotent() throws {
        try store.write(Data("x".utf8), to: "config.json")
        try store.delete("config.json")
        XCTAssertFalse(store.fileExists("config.json"))
        XCTAssertNoThrow(try store.delete("config.json"))
    }

    func testDefaultDirectoryIsApplicationSupportTapper() throws {
        let url = try XCTUnwrap(AtomicFileStore.defaultDirectory())
        XCTAssertEqual(url.lastPathComponent, "Tapper")
        XCTAssertTrue(url.path.contains("Application Support"), url.path)
    }
}
