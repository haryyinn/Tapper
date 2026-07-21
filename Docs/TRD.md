# 01_TRD.md

> **Tapper — Technical Requirements Document (TRD)**
>
> **Version:** 1.0 (Draft)
>
> **Status:** Engineering Baseline

---

# 1. Introduction

## 1.1 Purpose

This Technical Requirements Document (TRD) defines the engineering requirements for **Tapper**, a deterministic macOS application that recognizes taps on a laptop chassis using the built-in microphone and executes user-configured actions.

This document bridges the Product Requirements Document (PRD) and the implementation architecture by specifying measurable, testable, and implementation-independent requirements.

## 1.2 Scope

Version 1 includes:

- Apple Silicon macOS support
- Deterministic tap recognition
- Four interaction zones
- Calibration
- Configurable command mappings
- Local diagnostics
- Offline operation

Out of scope:

- AI / ML
- Cloud processing
- Cross-platform support
- Gesture recognition
- Context-aware automation

---

# 2. Operational Environment

- Hardware: Apple Silicon MacBook
- OS: macOS 14+
- Required Permissions:
  - Microphone
  - Accessibility
  - Automation (Apple Events)
- Optional:
  - Notifications
  - Launch at Login

---

# 3. System Constraints

| ID | Requirement |
|----|-------------|
| SC-001 | The system shall use only public macOS APIs. |
| SC-002 | The system shall operate fully offline. |
| SC-003 | The system shall not use AI or Machine Learning. |
| SC-004 | Recognition shall be deterministic. |
| SC-005 | Only built-in hardware shall be required. |
| SC-006 | User data shall remain local by default. |

---

# 4. Functional Requirements

## Audio Acquisition

| ID | Requirement |
|----|-------------|
| FR-AA-001 | Continuously monitor the selected microphone while Tapper is enabled. |
| FR-AA-002 | Use a rolling audio buffer. |
| FR-AA-003 | Allow microphone selection if multiple inputs exist. |
| FR-AA-004 | Detect microphone loss. |
| FR-AA-005 | Recover automatically when available. |
| FR-AA-006 | Timestamp incoming audio frames. |
| FR-AA-007 | Reject corrupted buffers. |

## Signal Processing

| ID | Requirement |
|----|-------------|
| FR-SP-001 | Normalize captured samples. |
| FR-SP-002 | Apply configurable filtering. |
| FR-SP-003 | Extract transient impulses. |
| FR-SP-004 | Remove DC offset. |
| FR-SP-005 | Compute required signal features. |
| FR-SP-006 | Support configurable thresholds. |
| FR-SP-007 | Forward candidate taps to detection. |

## Tap Detection

| ID | Requirement |
|----|-------------|
| FR-TD-001 | Detect intentional taps. |
| FR-TD-002 | Ignore typing. |
| FR-TD-003 | Ignore trackpad clicks. |
| FR-TD-004 | Ignore charger insertion. |
| FR-TD-005 | Ignore lid closure. |
| FR-TD-006 | Ignore laptop movement. |
| FR-TD-007 | Reject duplicate detections. |
| FR-TD-008 | Produce a Tap Event object. |

## Zone Classification

| ID | Requirement |
|----|-------------|
| FR-ZC-001 | Support four fixed interaction zones. |
| FR-ZC-002 | Use calibration data. |
| FR-ZC-003 | Produce exactly one zone classification. |
| FR-ZC-004 | Reject ambiguous classifications. |
| FR-ZC-005 | Support recalibration. |

## Command Mapping

| ID | Requirement |
|----|-------------|
| FR-CM-001 | Associate each zone with one command. |
| FR-CM-002 | Persist mappings locally. |
| FR-CM-003 | Validate mappings before saving. |
| FR-CM-004 | Restore defaults. |

## Command Execution

| ID | Requirement |
|----|-------------|
| FR-CE-001 | Execute keyboard shortcuts. |
| FR-CE-002 | Execute Apple Shortcuts. |
| FR-CE-003 | Execute AppleScript. |
| FR-CE-004 | Execute shell commands. |
| FR-CE-005 | Execute local executables. |
| FR-CE-006 | Abort execution on permission failure. |

## Configuration

| ID | Requirement |
|----|-------------|
| FR-CF-001 | Store user preferences locally. |
| FR-CF-002 | Store calibration profiles. |
| FR-CF-003 | Support export/import of configuration (future-compatible). |

## Diagnostics

| ID | Requirement |
|----|-------------|
| FR-DG-001 | Log application events locally. |
| FR-DG-002 | Log errors. |
| FR-DG-003 | Export diagnostics bundle containing logs, calibration, configuration, OS version, app version, and optional captured audio. |

## System Integration

| ID | Requirement |
|----|-------------|
| FR-SI-001 | Support launch at login. |
| FR-SI-002 | Detect revoked permissions. |
| FR-SI-003 | Notify the user of unrecoverable failures. |

---

# 5. Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-001 | Tap detection latency ≤100 ms. |
| NFR-002 | End-to-end latency ≤200 ms. |
| NFR-003 | Prototype accuracy ≥80%. |
| NFR-004 | Release accuracy target ≥95%. |
| NFR-005 | Operate without internet. |
| NFR-006 | Modular architecture. |
| NFR-007 | Maintain deterministic behavior. |
| NFR-008 | Local-first data storage. |
| NFR-009 | Graceful degradation on permission loss. |

---

# 6. External Interfaces

## Inputs

- Built-in microphone

## Outputs

- CGEvent keyboard events
- Apple Shortcuts
- AppleScript
- POSIX shell
- Local executables

## macOS Services

- AVFoundation
- Core Audio
- Accelerate
- Accessibility
- UserNotifications
- SMAppService

---

# 7. Data Requirements

Persistent:

- Preferences
- Calibration
- Command mappings
- Diagnostic logs

Ephemeral:

- PCM buffers
- DSP features
- Tap events
- Zone classifications

---

# 8. Error Handling

- Missing microphone → pause recognition.
- Accessibility revoked → disable execution.
- Missing calibration → require recalibration.
- Corrupt configuration → restore defaults.

---

# 9. Security & Privacy

- Offline by default.
- No cloud transmission.
- No permanent audio storage unless exported.
- Commands execute under user privileges.
- User confirmation required before saving destructive shell commands.

---

# 10. Assumptions

- Laptop on rigid surface.
- Functional microphone.
- User calibration completed.
- Required permissions granted.

---

# 11. Risks

- Hardware acoustic variation.
- Environmental noise.
- Future macOS API changes.
- Microphone placement differences.

---

# 12. Acceptance Criteria

- Detect taps.
- Correctly classify all four zones.
- Execute mapped actions.
- Meet latency targets.
- Meet prototype accuracy.
- Operate offline.

---

# 13. Requirement Traceability

| PRD Goal | Technical Requirements |
|-----------|------------------------|
| Offline First | SC-002, NFR-005 |
| Deterministic Recognition | SC-003, SC-004, NFR-007 |
| Four Zones | FR-ZC-* |
| Command Execution | FR-CE-* |
| Calibration | FR-CF-002, FR-ZC-002 |
| Diagnostics | FR-DG-* |

---

# End of Document
