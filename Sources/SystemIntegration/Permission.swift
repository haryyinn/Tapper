/// A permission Tapper may require (`API_REFERENCE` §9, `TRD` §2).
public enum PermissionKind: String, Sendable, Equatable, CaseIterable {

    /// Required for audio capture.
    case microphone

    /// Required to post synthetic keyboard events.
    case accessibility

    /// Required to send Apple Events to other applications.
    case automation

    /// Optional; used for user-facing alerts.
    case notifications

    /// Whether recognition and command execution require this permission
    /// (`IMPLEMENTATION_RULES` §Permissions: Microphone, Accessibility, and
    /// Automation are required; Notifications is optional).
    public var isRequired: Bool { self != .notifications }
}

/// The authorization state of a permission.
public enum PermissionStatus: String, Sendable, Equatable {

    /// The user has not been asked, or the state cannot be determined without
    /// prompting.
    case notDetermined

    /// The permission is granted.
    case authorized

    /// The permission was denied by the user.
    case denied

    /// The permission is restricted and cannot be granted by the user.
    case restricted

    /// Whether the permission currently allows the associated capability.
    public var allowsUse: Bool { self == .authorized }
}
