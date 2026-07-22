import AVFoundation

/// The microphone authorization state relevant to audio capture.
///
/// Mirrors the platform authorization states while keeping the Audio subsystem's
/// public surface independent of AVFoundation enum evolution.
public enum MicrophoneAuthorizationStatus: Sendable, Equatable {

    /// The user has not yet been asked to grant microphone access.
    case notDetermined

    /// Microphone access is granted.
    case authorized

    /// Microphone access was denied by the user.
    case denied

    /// Microphone access is restricted and cannot be granted by the user.
    case restricted

    /// Maps a platform authorization status, treating unknown values as denied
    /// so capture fails safely.
    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }

    /// Whether microphone capture may proceed in this state.
    public var allowsCapture: Bool { self == .authorized }
}

/// Queries and requests microphone authorization.
///
/// The Audio subsystem observes and requests microphone access because capture
/// cannot proceed without it (`SYSTEM_DESIGN` §1). Broader system permissions
/// (Accessibility, Automation) are owned by the System subsystem.
public enum MicrophoneAuthorization {

    /// The current microphone authorization status.
    public static var current: MicrophoneAuthorizationStatus {
        MicrophoneAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// Requests microphone access from the user if not yet determined.
    ///
    /// - Returns: The resulting authorization status.
    public static func requestAccess() async -> MicrophoneAuthorizationStatus {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return current
    }
}
