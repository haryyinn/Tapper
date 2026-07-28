import Calibration
import XCTest

@testable import Inspection

/// Tests the geometric summary of the labelled dataset (ADR-016 §5).
final class FeatureSpaceReportTests: XCTestCase {

    /// Four samples at distance 1 from the origin along each axis pair give a
    /// mean radius of exactly 1 and a maximum of exactly 1.
    func testZoneSpreadOverUnitCircle() throws {
        let report = FeatureSpaceReport.make(samplesByZone: [
            "topLeft": [[1, 0], [-1, 0], [0, 1], [0, -1]]
        ])
        let zone = try XCTUnwrap(report.zones.first)

        XCTAssertEqual(zone.count, 4)
        XCTAssertEqual(zone.meanRadius, 1.0, accuracy: 1e-12)
        XCTAssertEqual(zone.maximumRadius, 1.0, accuracy: 1e-12)
        XCTAssertEqual(zone.outliers, 0)
    }

    /// A sample far from its zone's centroid is counted as an outlier, and a
    /// tight cluster reports none.
    func testOutlierDetection() {
        let tight = (0..<10).map { [Double($0) * 0.01, 0.0] }
        XCTAssertEqual(
            FeatureSpaceReport.make(samplesByZone: ["topLeft": tight]).zones[0].outliers, 0)

        let withOutlier = tight + [[50.0, 0.0]]
        XCTAssertEqual(
            FeatureSpaceReport.make(samplesByZone: ["topLeft": withOutlier]).zones[0].outliers, 1)
    }

    /// Two clusters 10 apart with mean radii of 1 each have a separation ratio
    /// of 10 / 2 = 5, which is well clear of overlap.
    func testSeparatedZones() throws {
        let report = FeatureSpaceReport.make(samplesByZone: [
            "topLeft": [[1, 0], [-1, 0], [0, 1], [0, -1]],
            "topRight": [[11, 0], [9, 0], [10, 1], [10, -1]],
        ])
        let pair = try XCTUnwrap(report.pairs.first)

        XCTAssertEqual(pair.centroidDistance, 10.0, accuracy: 1e-12)
        XCTAssertEqual(pair.combinedSpread, 2.0, accuracy: 1e-12)
        XCTAssertEqual(pair.separation, 5.0, accuracy: 1e-12)
    }

    /// Two clusters 1 apart with mean radii of 1 each have a ratio of 0.5, so
    /// their typical extents reach past each other — the condition the report
    /// exists to surface.
    func testOverlappingZonesReportRatioBelowOne() throws {
        let report = FeatureSpaceReport.make(samplesByZone: [
            "topLeft": [[1, 0], [-1, 0], [0, 1], [0, -1]],
            "topRight": [[2, 0], [0, 0], [1, 1], [1, -1]],
        ])
        let pair = try XCTUnwrap(report.pairs.first)

        XCTAssertEqual(pair.centroidDistance, 1.0, accuracy: 1e-12)
        XCTAssertEqual(pair.separation, 0.5, accuracy: 1e-12)
        XCTAssertLessThan(pair.separation, 1.0)
    }

    /// Zones are reported in canonical order and every pair appears once.
    func testPairsAreCanonicalAndComplete() {
        let samples = [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]
        let report = FeatureSpaceReport.make(samplesByZone: [
            "bottomRight": samples, "topLeft": samples, "topRight": samples,
        ])

        XCTAssertEqual(report.zones.map(\.zone), ["topLeft", "topRight", "bottomRight"])
        XCTAssertEqual(report.pairs.count, 3)
        XCTAssertEqual(
            report.pairs.map { "\($0.first)|\($0.second)" },
            ["topLeft|topRight", "topLeft|bottomRight", "topRight|bottomRight"])
    }

    /// A zone with no samples contributes nothing rather than a zero-sized
    /// cluster that would distort the pair statistics.
    func testEmptyZonesAreExcluded() {
        let report = FeatureSpaceReport.make(samplesByZone: [
            "topLeft": [[0.0, 0.0], [1.0, 0.0]], "topRight": [],
        ])
        XCTAssertEqual(report.zones.map(\.zone), ["topLeft"])
        XCTAssertTrue(report.pairs.isEmpty)
    }
}
