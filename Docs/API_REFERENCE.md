# 05_API_REFERENCE.md

> **Tapper — API & Framework Reference**
>
> Version: 1.0 (Draft)

---

# 1. Purpose

This document maps every Tapper subsystem to the macOS APIs and frameworks required for implementation. It explains why each API is used, how it fits into the architecture, required permissions, lifecycle considerations, and alternatives.

---

# 2. Framework Overview

| Framework | Purpose | Required |
|-----------|---------|----------|
| AVFoundation | Audio capture | Yes |
| Core Audio | Low-level audio interfaces | Yes |
| Accelerate (vDSP) | DSP operations | Yes |
| Core Graphics | Keyboard event generation | Yes |
| ApplicationServices (Accessibility) | UI automation & permissions | Yes |
| Foundation | Files, preferences, processes | Yes |
| UserNotifications | Optional notifications | Optional |
| ServiceManagement (SMAppService) | Launch at Login | Optional |
| OSLog | Logging | Yes |

---

# 3. Audio Stack

## AVFoundation

### Purpose
Primary real-time microphone capture.

### Responsibilities
- AVAudioEngine lifecycle
- Input node access
- Audio taps
- PCM buffer delivery

### Used By
- Audio Acquisition subsystem

### Notes
Chosen for stable high-level audio capture.

---

## Core Audio

### Purpose
Hardware-level audio information.

### Responsibilities
- Audio device enumeration
- Sample format details
- Device monitoring

### Used By
- Audio Acquisition

---

# 4. Digital Signal Processing

## Accelerate (vDSP)

### Purpose
High-performance DSP.

### Operations
- Vector math
- RMS
- FFT
- Convolution
- Filtering
- Window functions
- Peak analysis

### Used By
- Signal Processing

Reason:
Optimized Apple Silicon implementation.

---

# 5. Command Execution

## Core Graphics

Purpose:
Synthetic keyboard events.

Functions
- CGEvent
- CGEventPost

Used for
- Keyboard shortcuts

---

## Process

Purpose:
Execute local executables and shell commands.

Capabilities
- Launch binaries
- Execute shell scripts
- Capture exit status

---

## AppleScript

Purpose
Application automation.

Use Cases
- Finder automation
- Document automation
- Apple Events

---

## Shortcuts Integration

Purpose

Execute user-created Apple Shortcuts.

---

# 6. System Services

## Accessibility

Purpose

UI automation and privileged event generation.

Required For

- Keyboard injection
- Future dialog interaction

Permission

Accessibility permission required.

---

## UserNotifications

Purpose

Display optional notifications.

Examples

- Permission missing
- Calibration required
- Recognition paused

---

## SMAppService

Purpose

Launch Tapper automatically after login.

---

# 7. Configuration APIs

## UserDefaults

Stores

- Preferences
- UI settings
- Runtime options

---

## FileManager

Stores

- Calibration
- Logs
- Diagnostic bundles
- Exported configuration

---

# 8. Logging

## OSLog

Purpose

Structured logging.

Log Categories

- Audio
- DSP
- Recognition
- Execution
- Configuration
- Errors

---

# 9. Permissions Matrix

| Permission | Why Required |
|------------|--------------|
| Microphone | Audio capture |
| Accessibility | Keyboard events |
| Automation | Apple Events |
| Notifications | Optional alerts |

---

# 10. API Lifecycle

Startup

1. Load configuration
2. Request permissions
3. Initialize AVAudioEngine
4. Start capture

Runtime

1. Receive audio
2. Process signal
3. Execute commands
4. Write logs

Shutdown

1. Stop engine
2. Flush logs
3. Save configuration

---

# 11. Error Handling

| API | Failure | Recovery |
|-----|----------|----------|
| AVFoundation | Mic unavailable | Retry |
| Accessibility | Permission revoked | Disable execution |
| FileManager | Write failure | Report & continue |
| Process | Non-zero exit | Log failure |
| AppleScript | Script error | Report error |

---

# 12. Future APIs

Potential future integrations:

- NSWorkspace
- UniformTypeIdentifiers
- SwiftData
- Endpoint Security (research only)
- App Intents

These are not required for Version 1.

---

# 13. Alternatives Considered

| Decision | Selected | Reason |
|----------|----------|--------|
| Audio | AVFoundation | Native, stable |
| DSP | Accelerate | Optimized on Apple Silicon |
| Config | UserDefaults + FileManager | Simple and local |
| Logging | OSLog | Native structured logging |
| Startup | SMAppService | Modern macOS approach |

---

# 14. Framework-to-Subsystem Mapping

| Subsystem | Primary APIs |
|-----------|--------------|
| Audio Acquisition | AVFoundation, Core Audio |
| Signal Processing | Accelerate |
| Tap Detection | Accelerate |
| Zone Classification | Internal algorithms |
| Command Mapping | Foundation |
| Command Execution | Core Graphics, Process, AppleScript |
| Configuration | UserDefaults, FileManager |
| Diagnostics | OSLog, FileManager |
| System Integration | Accessibility, UserNotifications, SMAppService |

---

# 15. Summary

Tapper Version 1 is implementable using only public macOS APIs. The chosen framework set supports deterministic offline recognition, low-latency processing, and native integration while remaining maintainable and extensible.

---

# End of Document
