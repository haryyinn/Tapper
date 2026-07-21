# 03_ARCHITECTURE.md

> **Tapper — Software Architecture Document**
>
> Version: 1.0 (Draft)

---

# 1. Purpose

This document defines the internal software architecture of Tapper. It specifies the runtime components, their responsibilities, interfaces, data ownership, execution flow, persistence strategy, threading model, and extensibility principles. The architecture is implementation-oriented while remaining independent of specific code structure.

---

# 2. Architectural Principles

- Offline First
- Deterministic Recognition
- Single Responsibility per Component
- Modular Design
- Local Data Ownership
- Explainable Signal Processing
- Fail Safely
- Extensible Command Execution

---

# 3. High-Level Architecture

```text
                User
                  │
                  ▼
      ┌────────────────────┐
      │ Audio Acquisition  │
      └────────────────────┘
                  │
                  ▼
      ┌────────────────────┐
      │ Signal Processing  │
      └────────────────────┘
                  │
                  ▼
      ┌────────────────────┐
      │   Tap Detection    │
      └────────────────────┘
                  │
                  ▼
      ┌────────────────────┐
      │ Zone Classification│
      └────────────────────┘
                  │
                  ▼
      ┌────────────────────┐
      │ Command Mapping    │
      └────────────────────┘
                  │
                  ▼
      ┌────────────────────┐
      │ Command Execution  │
      └────────────────────┘
                  │
                  ▼
             Diagnostics
```

---

# 4. Component Architecture

## 4.1 Audio Acquisition

Responsibilities

- Capture microphone input
- Maintain rolling PCM buffer
- Timestamp samples
- Detect device availability

Input

- Built-in microphone

Output

- PCM audio frames

Dependencies

- AVAudioEngine
- Core Audio

---

## 4.2 Signal Processing

Responsibilities

- Normalize signal
- Remove DC offset
- Filter noise
- Compute features
- Generate candidate impulses

Input

- PCM frames

Output

- Processed feature vectors

Dependencies

- Accelerate (vDSP)

---

## 4.3 Tap Detection

Responsibilities

- Detect transient acoustic impulses
- Reject environmental events
- Generate TapEvent objects

Input

- Feature vectors

Output

- TapEvent

---

## 4.4 Zone Classification

Responsibilities

- Determine tap region
- Use calibration profile
- Reject ambiguous events

Input

- TapEvent
- Calibration

Output

- Zone ID

---

## 4.5 Command Mapping

Responsibilities

- Resolve zone to action
- Validate configuration

Input

- Zone ID

Output

- Executable command

---

## 4.6 Command Execution

Responsibilities

- Dispatch keyboard shortcuts
- Execute AppleScript
- Execute Apple Shortcuts
- Execute shell commands
- Execute binaries

Output

- Execution status

---

## 4.7 Configuration Manager

Responsibilities

- Preferences
- Calibration
- Command mappings
- Import/export

Persistent Storage

- Local configuration directory

---

## 4.8 Diagnostics Manager

Responsibilities

- Logging
- Diagnostics bundle
- Error reporting

Artifacts

- Logs
- Configuration snapshot
- Calibration
- Metadata

---

## 4.9 System Integration

Responsibilities

- Permissions
- Login Item
- Notifications
- Accessibility integration

---

# 5. Runtime Pipeline

```text
Microphone
      │
Rolling Buffer
      │
Signal Processing
      │
Candidate Detection
      │
Tap Detection
      │
Zone Classification
      │
Command Lookup
      │
Command Execution
      │
Diagnostics
```

---

# 6. Component Interfaces

| Producer | Consumer | Data |
|-----------|----------|------|
| Audio Acquisition | Signal Processing | PCM Frames |
| Signal Processing | Tap Detection | Feature Vector |
| Tap Detection | Zone Classification | TapEvent |
| Zone Classification | Command Mapping | Zone ID |
| Command Mapping | Command Execution | Command Descriptor |
| All Components | Diagnostics | Events & Errors |

---

# 7. Threading Model

Dedicated Audio Thread
- Continuous microphone capture.

DSP Worker
- Signal processing.

Recognition Worker
- Tap detection and classification.

Main Thread
- Configuration, permissions, notifications.

Execution Thread
- Command dispatch.

No component shall block the audio capture thread.

---

# 8. State Management

Application States

```text
Stopped
   │
Starting
   │
Idle
   │
Listening
   │
Recognized
   │
Executing
   │
Listening
```

Failure states

- Permission Lost
- Microphone Lost
- Configuration Invalid
- Calibration Required

---

# 9. Persistence Architecture

Persistent

- Preferences
- Calibration
- Command mappings
- Logs

Transient

- PCM buffers
- Feature vectors
- Tap events
- Classification results

---

# 10. Startup Lifecycle

1. Launch
2. Load configuration
3. Verify permissions
4. Load calibration
5. Initialize audio engine
6. Start rolling buffer
7. Begin recognition

Shutdown

1. Stop capture
2. Flush logs
3. Save configuration
4. Release resources

---

# 11. Error Recovery

| Failure | Recovery |
|----------|----------|
| Microphone unavailable | Retry automatically |
| Permission revoked | Disable execution |
| Invalid calibration | Prompt recalibration |
| Corrupt configuration | Restore defaults |

---

# 12. Security Architecture

- Offline processing
- Local storage only
- No cloud dependency
- No persistent audio without explicit export
- Commands execute under current user privileges

---

# 13. Extensibility

Future extensions shall not require redesign of the recognition pipeline.

Planned capabilities include:

- Multi-tap recognition
- Context-aware mappings
- Application-specific profiles
- Additional interaction zones
- Cross-platform support
- Plugin-based command providers

---

# 14. Framework Mapping

| Component | Framework |
|-----------|-----------|
| Audio Acquisition | AVFoundation, Core Audio |
| Signal Processing | Accelerate |
| Command Execution | Core Graphics, Process, AppleScript |
| Configuration | UserDefaults, FileManager |
| Diagnostics | OSLog, FileManager |
| System Integration | Accessibility, UserNotifications, SMAppService |

---

# 15. Architectural Decisions

- Deterministic DSP over machine learning.
- Fixed interaction zones in Version 1.
- Single responsibility for each subsystem.
- Separation of recognition and execution pipelines.
- Local-first data ownership.
- Public macOS APIs only.

---

# End of Document
