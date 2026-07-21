import XCTest

@testable import Tapper

/// Phase 0 bootstrap smoke test.
///
/// Verifies that the package compiles, the `Tapper` library links into the test
/// target, and the XCTest harness builds and runs. Behavioral tests for each
/// subsystem are added alongside their implementations in later phases.
final class BootstrapTests: XCTestCase {
    func testTestHarnessRuns() {
        XCTAssertTrue(true, "Bootstrap: the XCTest harness executes for the package.")
    }
}
