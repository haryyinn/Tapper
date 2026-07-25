import XCTest

@testable import SystemIntegration

final class PermissionTests: XCTestCase {

    func testRequiredPermissionsMatchDocumentedMatrix() {
        XCTAssertTrue(PermissionKind.microphone.isRequired)
        XCTAssertTrue(PermissionKind.accessibility.isRequired)
        XCTAssertTrue(PermissionKind.automation.isRequired)
        XCTAssertFalse(PermissionKind.notifications.isRequired, "notifications are optional")
    }

    func testOnlyAuthorizedAllowsUse() {
        XCTAssertTrue(PermissionStatus.authorized.allowsUse)
        XCTAssertFalse(PermissionStatus.notDetermined.allowsUse)
        XCTAssertFalse(PermissionStatus.denied.allowsUse)
        XCTAssertFalse(PermissionStatus.restricted.allowsUse)
    }

    func testAutomationIsNotProbed() {
        XCTAssertEqual(
            AutomationPermission.status, .notDetermined,
            "Automation must not be probed at startup")
    }

    func testAccessibilityStatusIsQueryableWithoutPrompting() {
        // Host-dependent value; the contract is that reading it is safe and
        // yields one of the two representable states.
        XCTAssertTrue([.authorized, .denied].contains(AccessibilityPermission.status))
    }
}

final class SystemCapabilitiesTests: XCTestCase {

    private func capabilities(
        microphone: PermissionStatus,
        accessibility: PermissionStatus = .authorized
    ) -> SystemCapabilities {
        SystemCapabilities(
            microphone: microphone, accessibility: accessibility, automation: .notDetermined)
    }

    func testRecognitionRequiresOnlyMicrophone() {
        XCTAssertTrue(
            capabilities(microphone: .authorized, accessibility: .denied).allowsRecognition)
        XCTAssertFalse(capabilities(microphone: .denied).allowsRecognition)
    }

    func testKeyboardCommandsRequireAccessibility() {
        XCTAssertTrue(
            capabilities(microphone: .authorized, accessibility: .authorized).allowsKeyboardCommands
        )
        XCTAssertFalse(
            capabilities(microphone: .authorized, accessibility: .denied).allowsKeyboardCommands)
    }

    func testMissingRequiredPermissionsAreReported() {
        XCTAssertEqual(
            capabilities(microphone: .denied, accessibility: .denied).missingRequiredPermissions,
            [.microphone, .accessibility])
        XCTAssertEqual(
            capabilities(microphone: .authorized, accessibility: .authorized)
                .missingRequiredPermissions,
            [])
    }

    func testAutomationIsNeverReportedMissing() {
        let capabilities = SystemCapabilities(
            microphone: .authorized, accessibility: .authorized, automation: .notDetermined)
        XCTAssertFalse(capabilities.missingRequiredPermissions.contains(.automation))
    }
}
