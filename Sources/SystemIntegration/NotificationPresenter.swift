import Foundation
import UserNotifications

/// Presents user-facing alerts for unrecoverable failures (`TRD` FR-SI-003).
///
/// Notifications are optional (`API_REFERENCE` §9): if they are unavailable or
/// denied, the failure is still handled by the runtime and the application keeps
/// running. Presenting a notification never influences runtime behavior.
public protocol NotificationPresenting: Sendable {

    /// Presents a notification describing an unrecoverable failure.
    ///
    /// Implementations must not throw: a notification failure is never allowed
    /// to affect the runtime.
    ///
    /// - Parameters:
    ///   - title: A short factual title.
    ///   - body: A short factual description.
    func presentFailure(title: String, body: String)
}

/// A ``NotificationPresenting`` backed by `UserNotifications`
/// (`API_REFERENCE` §6).
///
/// Delivery is best effort: authorization requests and delivery failures are
/// ignored, because an optional notification must never change application
/// behavior. Message text is supplied by the caller and kept factual.
///
/// - Note: requires a bundled application context, so it is exercised through
///   integration testing rather than unit tests.
public struct UserNotificationPresenter: NotificationPresenting {

    /// Creates a notification presenter.
    public init() {}

    public func presentFailure(title: String, body: String) {
        // `UNUserNotificationCenter` is not `Sendable`, so the center is
        // re-obtained inside the completion handler rather than captured.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
}
