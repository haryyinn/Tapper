import ApplicationServices

/// Reports whether the process is trusted for Accessibility, which macOS
/// requires before synthetic keyboard events may be posted
/// (`API_REFERENCE` §6, §9).
///
/// Read-only: the status is observed, never requested here. Prompting the user
/// is a user-interface concern, and an unexpected prompt at startup would
/// violate the principle of least surprise.
public enum AccessibilityPermission {

    /// The current Accessibility authorization status.
    ///
    /// macOS exposes only a trusted/not-trusted signal, so an untrusted process
    /// is reported as ``PermissionStatus/denied`` — the state that correctly
    /// blocks keyboard command execution.
    public static var status: PermissionStatus {
        AXIsProcessTrusted() ? .authorized : .denied
    }
}

/// Reports the Automation (Apple Events) permission state
/// (`API_REFERENCE` §6, §9).
///
/// macOS determines Automation authorization **per target application**, and
/// querying it can present a user prompt. Tapper therefore never probes
/// Automation at startup: the status is reported as
/// ``PermissionStatus/notDetermined`` unless a specific target is being
/// evaluated, and an actual denial surfaces through the AppleScript provider's
/// existing execution-failure path.
public enum AutomationPermission {

    /// The Automation status when no specific target is being evaluated.
    public static var status: PermissionStatus { .notDetermined }
}
