import XCTest

@testable import SystemIntegration

/// A launch-at-login double that records calls without touching system state.
private final class SpyLaunchAtLogin: LaunchAtLoginControlling, @unchecked Sendable {
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    var state: LaunchAtLoginState = .disabled

    func enable() throws {
        enableCount += 1
        state = .enabled
    }

    func disable() throws {
        disableCount += 1
        state = .disabled
    }
}

/// A notification double that records presentations without delivering any.
private final class SpyNotificationPresenter: NotificationPresenting, @unchecked Sendable {
    private(set) var presented: [(title: String, body: String)] = []

    func presentFailure(title: String, body: String) {
        presented.append((title, body))
    }
}

final class LaunchAtLoginTests: XCTestCase {

    func testDefaultStateIsDisabled() {
        XCTAssertEqual(SpyLaunchAtLogin().state, .disabled, "ADR-008: off by default")
    }

    func testEnableAndDisableAreExplicitUserActions() throws {
        let service = SpyLaunchAtLogin()
        try service.enable()
        XCTAssertEqual(service.state, .enabled)
        XCTAssertEqual(service.enableCount, 1)

        try service.disable()
        XCTAssertEqual(service.state, .disabled)
        XCTAssertEqual(service.disableCount, 1)
    }

    func testEveryDocumentedStateIsRepresentable() {
        XCTAssertEqual(
            Set(
                [
                    LaunchAtLoginState.enabled, .disabled, .requiresApproval, .unknown,
                ].map(\.rawValue)),
            ["enabled", "disabled", "requiresApproval", "unknown"]
        )
    }
}

final class NotificationPresenterTests: XCTestCase {

    func testPresenterRecordsFactualFailureMessages() {
        let presenter = SpyNotificationPresenter()
        presenter.presentFailure(title: "Recognition stopped", body: "Calibration is required.")

        XCTAssertEqual(presenter.presented.count, 1)
        XCTAssertEqual(presenter.presented.first?.title, "Recognition stopped")
        XCTAssertEqual(presenter.presented.first?.body, "Calibration is required.")
    }

    func testPresentingDoesNotThrow() {
        // The protocol is deliberately non-throwing: an optional notification
        // must never surface an error into the runtime.
        let presenter = SpyNotificationPresenter()
        presenter.presentFailure(title: "t", body: "b")
        presenter.presentFailure(title: "t", body: "b")
        XCTAssertEqual(presenter.presented.count, 2)
    }
}
