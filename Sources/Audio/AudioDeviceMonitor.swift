import AVFoundation

/// Detects availability of an audio input device.
///
/// Version 1 targets the built-in microphone only (ADR-003). This type reports
/// whether the system currently exposes a usable audio input, supporting
/// graceful handling when no microphone is present (`TRD` FR-AA-004).
///
/// Automatic recovery from device loss *during* capture is part of System
/// Integration (error recovery, `IMPLEMENTATION_PLAN` Phase 8, `ARCHITECTURE`
/// §11) and is intentionally not implemented in this acquisition-only phase.
public enum AudioDeviceMonitor {

    /// Whether the system currently exposes a default audio input device.
    public static var isAudioInputAvailable: Bool {
        AVCaptureDevice.default(for: .audio) != nil
    }
}
