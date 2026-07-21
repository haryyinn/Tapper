# Tapper – System Design

Version: 1.0

---

# Purpose

This document describes the high-level logical structure of Tapper.

It defines the major software subsystems, their responsibilities, interactions, and dependencies. This document intentionally avoids implementation-specific details, which are covered separately in the Architecture and Algorithm documents.

---

# Design Principles

The system is designed around the following principles:

- Separation of concerns
- Modularity
- Deterministic processing
- Extensibility
- Offline-first execution
- Privacy by design
- Platform-native integration

---

# High-Level System

```
                   Tapper
                      │
 ┌────────────────────┼────────────────────┐
 │                    │                    │
Input             Processing          Execution
 │                    │                    │
 ▼                    ▼                    ▼
Audio            Recognition        Command Engine
Acquisition         Engine
 │                    │
 └────────────┬───────┘
              │
              ▼
      Configuration Manager

              │
              ▼
         Diagnostics

              │
              ▼
      System Integration
```

---

# Subsystems

## 1. Audio Acquisition

### Responsibility

Acquire microphone data from macOS and provide continuous audio buffers to the recognition pipeline.

### Responsibilities

- Microphone selection
- Permission validation
- Audio streaming
- Buffer management
- Sample-rate handling

### Primary APIs

- AVFoundation
- Core Audio

### Output

PCM audio buffers

---

## 2. Signal Processing

### Responsibility

Transform raw audio into features suitable for deterministic recognition.

### Responsibilities

- Pre-processing
- Filtering
- Windowing
- Energy computation
- Peak detection
- Feature extraction

### Primary APIs

- Accelerate
- vDSP

### Output

Candidate tap events

---

## 3. Recognition Engine

### Responsibility

Determine whether an event is an intentional tap and identify its interaction zone.

### Responsibilities

- Tap detection
- False-positive rejection
- Zone classification
- Calibration application
- Confidence estimation

### Primary Components

- Custom deterministic algorithm

### Output

Recognized interaction zone

---

## 4. Command Engine

### Responsibility

Translate recognized interaction zones into user-defined actions.

### Responsibilities

- Command lookup
- Keyboard shortcuts
- Shell command execution
- AppleScript execution
- Apple Shortcuts execution

### Primary APIs

- CGEvent
- Process
- AppleScript

---

## 5. Configuration Manager

### Responsibility

Manage persistent user configuration and calibration data.

### Responsibilities

- Preferences
- Command mappings
- Startup configuration
- Calibration profiles

### Primary APIs

- UserDefaults
- FileManager

---

## 6. Diagnostics

### Responsibility

Collect operational information for debugging and troubleshooting.

### Responsibilities

- Logging
- Error reporting
- Export diagnostics
- Calibration export

### Primary APIs

- OSLog
- FileManager

---

## 7. System Integration

### Responsibility

Integrate Tapper with macOS system services.

### Responsibilities

- Accessibility permissions
- Login at startup
- Notifications
- Automation permissions

### Primary APIs

- Accessibility
- SMAppService
- UserNotifications

---

## 8. Interaction Layer (Future)

### Responsibility

Provide context-aware interaction with application dialogs and operating system interfaces.

### Planned Capabilities

- Dialog detection
- Modal interaction
- Dynamic tap mappings
- Application-specific behavior

### Primary APIs

- Accessibility
- NSWorkspace

---

# System Data Flow

```
User Tap
    │
    ▼
Audio Acquisition
    │
    ▼
Signal Processing
    │
    ▼
Recognition Engine
    │
    ▼
Command Engine
    │
    ▼
macOS
```

Supporting subsystems:

```
Configuration Manager
        │
        ├────────► Recognition Engine
        ├────────► Command Engine
        └────────► System Integration

Diagnostics
        ▲
        │
Observes all major subsystems
```

---

# Framework Mapping

| Subsystem | Primary Frameworks |
|------------|-------------------|
| Audio Acquisition | AVFoundation, Core Audio |
| Signal Processing | Accelerate (vDSP) |
| Recognition Engine | Custom Deterministic Algorithm |
| Command Engine | CGEvent, Process, AppleScript |
| Configuration Manager | UserDefaults, FileManager |
| Diagnostics | OSLog, FileManager |
| System Integration | Accessibility, SMAppService, UserNotifications |
| Interaction Layer (Future) | Accessibility, NSWorkspace |

---

# Design Notes

- Each subsystem has a single primary responsibility.
- Communication between subsystems should occur through well-defined interfaces.
- The Recognition Engine remains independent of macOS-specific APIs wherever possible.
- Platform-specific functionality is isolated within the System Integration and Command Engine subsystems.
- Future capabilities should be introduced as additional subsystems without modifying the existing recognition pipeline.