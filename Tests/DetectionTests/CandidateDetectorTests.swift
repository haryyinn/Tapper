import XCTest

@testable import Detection

final class CandidateDetectorTests: XCTestCase {

    func testPeakAtThresholdIsDetected() {
        let detector = CandidateDetector(peakThreshold: 0.05)
        XCTAssertTrue(detector.detectsCandidate(inFiltered: [0.0, 0.05, -0.01]))
    }

    func testPeakAboveThresholdIsDetected() {
        let detector = CandidateDetector(peakThreshold: 0.05)
        XCTAssertTrue(detector.detectsCandidate(inFiltered: [0.0, -0.5, 0.01]))
    }

    func testPeakBelowThresholdIsNotDetected() {
        let detector = CandidateDetector(peakThreshold: 0.05)
        XCTAssertFalse(detector.detectsCandidate(inFiltered: [0.0, 0.049, -0.02]))
    }

    func testEmptyFrameIsNotDetected() {
        let detector = CandidateDetector(peakThreshold: 0.05)
        XCTAssertFalse(detector.detectsCandidate(inFiltered: []))
    }

    func testDefaultThresholdIsApprovedValue() {
        XCTAssertEqual(CandidateDetector().peakThreshold, 0.05)
        XCTAssertEqual(DetectionConstants.detectionPeakThreshold, 0.05)
    }
}
