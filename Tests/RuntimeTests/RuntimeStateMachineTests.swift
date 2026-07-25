import XCTest

@testable import Runtime

final class RuntimeStateMachineTests: XCTestCase {

    // MARK: Documented transition table (ALGORITHM §21.15)

    func testDocumentedTransitions() {
        let documented: [(RuntimeState, RuntimeEvent, RuntimeState)] = [
            (.idle, .initializationComplete, .listening),
            (.listening, .candidateDetected, .processing),
            (.processing, .processingFinishedWithoutExecution, .listening),
            (.processing, .commandExecuted, .cooldown),
            (.cooldown, .cooldownExpired, .listening),
            (.error, .recovered, .listening),
            (.idle, .calibrationStarted, .calibrating),
            (.listening, .calibrationStarted, .calibrating),
            (.calibrating, .calibrationFinished, .idle),
        ]
        for (from, event, expected) in documented {
            XCTAssertEqual(
                RuntimeStateMachine.nextState(after: event, from: from), expected,
                "\(from) + \(event) should yield \(expected)")
        }
    }

    func testFatalErrorIsAcceptedFromEveryState() {
        for state in RuntimeState.allCases {
            XCTAssertEqual(
                RuntimeStateMachine.nextState(after: .fatalError, from: state), .error,
                "fatal error must be accepted from \(state)")
        }
    }

    // MARK: Rejected transitions

    func testUndocumentedTransitionsAreRejected() {
        let rejected: [(RuntimeState, RuntimeEvent)] = [
            (.idle, .candidateDetected),
            (.idle, .commandExecuted),
            (.listening, .cooldownExpired),
            (.listening, .commandExecuted),
            (.cooldown, .candidateDetected),
            (.calibrating, .candidateDetected),
            (.error, .candidateDetected),
            (.error, .initializationComplete),
        ]
        for (from, event) in rejected {
            XCTAssertNil(
                RuntimeStateMachine.nextState(after: event, from: from),
                "\(from) + \(event) must not transition")
        }
    }

    func testApplyingInvalidEventLeavesStateUnchanged() {
        var machine = RuntimeStateMachine(state: .listening)
        XCTAssertFalse(machine.apply(.cooldownExpired))
        XCTAssertEqual(machine.state, .listening)
    }

    // MARK: Sequences

    func testFullRecognitionCycleReturnsToListening() {
        var machine = RuntimeStateMachine()
        XCTAssertEqual(machine.state, .idle)
        XCTAssertTrue(machine.apply(.initializationComplete))
        XCTAssertEqual(machine.state, .listening)
        XCTAssertTrue(machine.apply(.candidateDetected))
        XCTAssertEqual(machine.state, .processing)
        XCTAssertTrue(machine.apply(.commandExecuted))
        XCTAssertEqual(machine.state, .cooldown)
        XCTAssertTrue(machine.apply(.cooldownExpired))
        XCTAssertEqual(machine.state, .listening)
    }

    func testRejectedCandidateReturnsToListeningWithoutCooldown() {
        var machine = RuntimeStateMachine(state: .listening)
        machine.apply(.candidateDetected)
        machine.apply(.processingFinishedWithoutExecution)
        XCTAssertEqual(machine.state, .listening, "no cooldown without execution")
    }

    func testErrorSuspendsFrameProcessingUntilRecovery() {
        var machine = RuntimeStateMachine(state: .listening)
        XCTAssertTrue(machine.acceptsAudioFrames)
        machine.apply(.fatalError)
        XCTAssertEqual(machine.state, .error)
        XCTAssertFalse(machine.acceptsAudioFrames, "recognition is suspended in error")
        machine.apply(.recovered)
        XCTAssertEqual(machine.state, .listening)
        XCTAssertTrue(machine.acceptsAudioFrames)
    }

    func testCalibrationSuspendsFrameProcessing() {
        var machine = RuntimeStateMachine(state: .listening)
        machine.apply(.calibrationStarted)
        XCTAssertEqual(machine.state, .calibrating)
        XCTAssertFalse(machine.acceptsAudioFrames)
    }

    // MARK: Determinism (§21.17)

    func testIdenticalEventSequencesProduceIdenticalStates() {
        let events: [RuntimeEvent] = [
            .initializationComplete, .candidateDetected, .commandExecuted, .cooldownExpired,
            .candidateDetected, .processingFinishedWithoutExecution,
        ]
        var first = RuntimeStateMachine()
        var second = RuntimeStateMachine()
        var firstStates: [RuntimeState] = []
        var secondStates: [RuntimeState] = []
        for event in events {
            first.apply(event)
            second.apply(event)
            firstStates.append(first.state)
            secondStates.append(second.state)
        }
        XCTAssertEqual(firstStates, secondStates)
        XCTAssertEqual(
            firstStates,
            [.listening, .processing, .cooldown, .listening, .processing, .listening])
    }
}
