import Foundation
import ServiceManagement

/// Whether Tapper is registered to launch at login.
public enum LaunchAtLoginState: String, Sendable, Equatable {

    /// Registered to launch at login.
    case enabled

    /// Not registered.
    case disabled

    /// Registration requires the user to approve Tapper in System Settings.
    case requiresApproval

    /// The state could not be determined.
    case unknown
}

/// Controls the Launch at Login registration (`TRD` FR-SI-001).
///
/// Behind a protocol so the runtime can be exercised without mutating the
/// user's login items.
public protocol LaunchAtLoginControlling: Sendable {

    /// The current registration state.
    var state: LaunchAtLoginState { get }

    /// Registers Tapper to launch at login.
    ///
    /// - Throws: An error if registration fails.
    func enable() throws

    /// Unregisters Tapper from launching at login.
    ///
    /// - Throws: An error if unregistration fails.
    func disable() throws
}

/// A ``LaunchAtLoginControlling`` backed by `SMAppService`
/// (`API_REFERENCE` §6).
///
/// Launch at Login is optional and **off by default** (`DECISIONS` ADR-008); it
/// changes only when the user asks for it. Registration mutates system state, so
/// it is exercised by integration testing rather than unit tests.
public struct SMAppServiceLaunchAtLogin: LaunchAtLoginControlling {

    /// Creates a launch-at-login controller.
    public init() {}

    public var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .disabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unknown
        @unknown default: return .unknown
        }
    }

    public func enable() throws {
        try SMAppService.mainApp.register()
    }

    public func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
