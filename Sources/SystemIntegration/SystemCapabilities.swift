/// A snapshot of the permissions available to Tapper.
///
/// Immutable and purely descriptive: it reports what the operating system
/// currently allows so the runtime can degrade gracefully (`TRD` NFR-009). It
/// makes no decisions and requests no permissions.
///
/// Microphone status is supplied by the Audio subsystem, which owns microphone
/// authorization; this type only aggregates.
public struct SystemCapabilities: Sendable, Equatable {

    /// Microphone authorization, as reported by the Audio subsystem.
    public let microphone: PermissionStatus

    /// Accessibility authorization.
    public let accessibility: PermissionStatus

    /// Automation authorization (``PermissionStatus/notDetermined`` unless a
    /// specific target is evaluated).
    public let automation: PermissionStatus

    /// Creates a capability snapshot.
    ///
    /// - Parameters:
    ///   - microphone: Microphone status from the Audio subsystem.
    ///   - accessibility: Accessibility status. Defaults to the live value.
    ///   - automation: Automation status. Defaults to the un-probed value.
    public init(
        microphone: PermissionStatus,
        accessibility: PermissionStatus = AccessibilityPermission.status,
        automation: PermissionStatus = AutomationPermission.status
    ) {
        self.microphone = microphone
        self.accessibility = accessibility
        self.automation = automation
    }

    /// Whether audio capture — and therefore recognition — may run.
    ///
    /// Only microphone access gates recognition. Accessibility and Automation
    /// affect individual command types and are reported per execution
    /// (`ALGORITHM` §26.13), so their absence must not stop recognition.
    public var allowsRecognition: Bool { microphone.allowsUse }

    /// Whether keyboard-shortcut commands may be executed.
    public var allowsKeyboardCommands: Bool { accessibility.allowsUse }

    /// The required permissions that are not currently granted.
    ///
    /// Automation is excluded: its status is intentionally not probed, so it is
    /// never reported as missing on this basis.
    public var missingRequiredPermissions: [PermissionKind] {
        var missing: [PermissionKind] = []
        if !microphone.allowsUse { missing.append(.microphone) }
        if !accessibility.allowsUse { missing.append(.accessibility) }
        return missing
    }
}
