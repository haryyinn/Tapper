import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import DSP
@testable import Detection
@testable import Features
@testable import Runtime

/// Characterization ("golden") tests pinning the observable behaviour of the
/// deterministic recognition chain.
///
/// These tests exist to make behavioural change **visible**. They assert exact
/// values — written as hexadecimal float literals so no decimal rounding is
/// involved — for fixed synthetic inputs. Any refactor or optimization that
/// alters recognition results, feature values, or detection decisions will fail
/// here rather than silently changing behaviour.
///
/// A failure is not automatically a defect: it means behaviour changed. The
/// change must then be justified against the governing documentation before the
/// baseline is updated.
///
/// - Note: these inputs are synthetic signals that validate the *mathematics* of
///   the pipeline. They are not acoustic recordings and say nothing about
///   real-world recognition accuracy, which requires hardware measurement.
final class BehaviouralBaselineTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameSize = 1920
    private let epoch = Date(timeIntervalSince1970: 0)

    /// A 2000 Hz decaying burst standing in for a tap transient.
    private func tapFrame() -> [Double] {
        (0..<frameSize).map {
            0.5 * exp(-Double($0) / 400) * sin(2 * Double.pi * 2000 * Double($0) / sampleRate)
        }
    }

    /// A quiet 1000 Hz tone standing in for ambient noise.
    private func noiseFrame() -> [Double] {
        (0..<frameSize).map { 0.001 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate) }
    }

    // MARK: DSP baseline

    func testButterworthResponseBaseline() {
        let filter = ButterworthBandpass.v1
        XCTAssertEqual(filter.magnitudeResponse(atHz: 0), 0)
        XCTAssertEqual(filter.magnitudeResponse(atHz: 300), 0x1.6a09e6952618p-1)
        XCTAssertEqual(filter.magnitudeResponse(atHz: 6000), 0x1.6a09e695261ep-1)
        XCTAssertEqual(filter.magnitudeResponse(atHz: 24_000), 0x1.83f7142a1f4acp-111)
    }

    func testPreprocessingBaseline() {
        let dcRemoved = SignalPreprocessing.removeDCOffset(tapFrame())
        let filtered = ButterworthBandpass.v1.process(dcRemoved)
        let (normalized, peak) = SignalPreprocessing.peakNormalized(filtered)

        XCTAssertEqual(peak, 0x1.13ce1f2292af9p-1)
        XCTAssertEqual(normalized[100], 0x1.104077e541cbep-1)
        XCTAssertEqual(normalized.count, frameSize)
    }

    // MARK: Feature baseline

    func testFeatureVectorBaseline() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let vector = try XCTUnwrap(pipeline.extract(from: tapFrame()))

        XCTAssertEqual(vector.peakAmplitude, 0x1.13ce1f2292af9p-1)
        XCTAssertEqual(vector.rmsEnergy, 0x1.b10898678b725p-3)
        XCTAssertEqual(vector.spectralCentroid, 0x1.f30d3aa151e21p+10)
        XCTAssertEqual(vector.spectralBandwidth, 0x1.9088640c42786p+6)
        XCTAssertEqual(vector.spectralRollOff, 0x1.f7e8p+10)
        XCTAssertEqual(vector.dominantFrequency, 0x1.f20cp+10)
        XCTAssertEqual(vector.zeroCrossingRate, 0x1.5555555555555p-4)
        XCTAssertEqual(vector.attackTime, 0x1.6aaaaaaaaaaabp-2)
        XCTAssertEqual(vector.decayTime, 0x1p-3)
        XCTAssertEqual(vector.signalDuration, 0x1.25aaaaaaaaaabp+4)
    }

    func testFeatureExtractionIsRepeatable() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let frame = tapFrame()
        XCTAssertEqual(pipeline.extract(from: frame), pipeline.extract(from: frame))
    }

    // MARK: Detection baseline

    func testDetectionBaseline() throws {
        var detector = try TapDetector.v1()

        XCTAssertEqual(detector.process(frame: noiseFrame(), at: epoch), .noCandidate)
        XCTAssertEqual(detector.currentNoiseFloorRMS, 0x1.71cbad421887ep-11)

        guard case .candidate = detector.process(frame: tapFrame(), at: epoch) else {
            return XCTFail("tap frame must yield a candidate at the baseline")
        }
    }

    // MARK: Classification baseline

    private func fixedProfiles(threshold: Double) -> [ZoneProfile] {
        let dimension = FeatureVector.dimension
        let identity = (0..<dimension).map { row in
            (0..<dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        return InteractionZone.calibratable.map { zone in
            ZoneProfile(
                zone: zone,
                meanVector: MeanVector(values: [Double](repeating: 0, count: dimension)),
                covarianceMatrix: CovarianceMatrix(values: identity),
                inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
                threshold: ThresholdModel(acceptanceThreshold: threshold, ambiguityMargin: 0))
        }
    }

    func testClassificationBaseline() throws {
        let pipeline = try FeatureExtractionPipeline.v1()
        let vector = try XCTUnwrap(pipeline.extract(from: tapFrame()))
        let dimension = FeatureVector.dimension
        let normalization = NormalizationParameters(
            means: [Double](repeating: 0, count: dimension),
            standardDeviations: [Double](repeating: 1, count: dimension))

        let outcome = ZoneClassifier().classify(
            featureVector: vector,
            profiles: fixedProfiles(threshold: 1_000_000),
            normalization: normalization,
            at: epoch)

        XCTAssertEqual(outcome.status, .success)
        XCTAssertEqual(outcome.zone, .topLeft, "canonical tie-break order")
        XCTAssertEqual(outcome.distance, 0x1.b17ec8a83af4ap+11)
        XCTAssertEqual(outcome.confidence, 0x1.8e9ce17504512p+6)
    }

    // MARK: State machine baseline

    func testStateSequenceBaseline() {
        var machine = RuntimeStateMachine()
        let events: [RuntimeEvent] = [
            .initializationComplete, .candidateDetected, .commandExecuted, .cooldownExpired,
            .candidateDetected, .processingFinishedWithoutExecution, .fatalError, .recovered,
        ]
        let states = events.map { event -> RuntimeState in
            machine.apply(event)
            return machine.state
        }
        XCTAssertEqual(
            states,
            [
                .listening, .processing, .cooldown, .listening, .processing, .listening, .error,
                .listening,
            ])
    }
}
