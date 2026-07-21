# 08_DECISIONS.md

> **Tapper — Architecture Decision Records (ADR)**
>
> Version: 1.0 (Draft)

---

# Purpose

This document records the significant architectural and technical decisions made during the design of Tapper Version 1. Each decision includes the context, the chosen solution, the rationale, and the consequences. These records provide historical context for future contributors and help maintain consistency as the project evolves.

---

# ADR-001 — Offline-First Architecture

**Status:** Accepted

## Context
Tapper processes microphone input that may contain sensitive information. Network dependency would introduce privacy concerns and increase latency.

## Decision
All recognition, classification, calibration, and command execution shall occur locally.

## Rationale
- Privacy
- Reliability
- Lower latency
- No internet dependency

## Consequences
- No cloud synchronization in V1
- All user data remains on-device

---

# ADR-002 — Deterministic DSP over Machine Learning

**Status:** Accepted

## Context
Machine learning could improve adaptability but introduces opacity, model management, and inconsistent behavior.

## Decision
Use deterministic digital signal processing and rule-based classification.

## Rationale
- Explainable decisions
- Predictable output
- Easier debugging
- No model training

## Consequences
- Calibration becomes more important
- Algorithm improvements require engineering changes rather than retraining

---

# ADR-003 — Built-in Microphone Only

**Status:** Accepted

## Context
Supporting arbitrary microphones increases complexity and calibration variability.

## Decision
Version 1 targets the built-in microphone.

## Rationale
- Consistent hardware
- Simpler calibration
- Predictable acoustic response

## Consequences
- External microphones are outside V1 scope

---

# ADR-004 — Four Fixed Interaction Zones

**Status:** Accepted

## Context
Unlimited tap locations complicate recognition and reduce reliability.

## Decision
Support:
- Top Left
- Top Right
- Bottom Left
- Bottom Right

## Rationale
- Simplicity
- Higher accuracy
- Easier user mental model

## Consequences
Additional zones may be introduced in future versions.

---

# ADR-005 — Modular Pipeline

**Status:** Accepted

## Decision

Separate the application into:

- Audio Acquisition
- Signal Processing
- Tap Detection
- Zone Classification
- Command Mapping
- Command Execution
- Diagnostics
- Configuration

## Rationale
Single responsibility and easier testing.

---

# ADR-006 — Local Configuration Storage

**Status:** Accepted

## Decision

Persist:

- Preferences
- Calibration
- Command mappings
- Diagnostics

using local storage.

## Rationale
Supports offline-first operation.

---

# ADR-007 — Public Apple APIs Only

**Status:** Accepted

## Context
Private APIs risk application rejection and long-term instability.

## Decision
Use only documented public macOS APIs.

## Consequences
Future releases remain maintainable and compatible with macOS updates.

---

# ADR-008 — Launch at Login is Optional

**Status:** Accepted

## Decision
Provide Launch at Login as a configurable option rather than enabling it by default.

## Rationale
Respect user control and operating-system conventions.

---

# ADR-009 — Fail Safe

**Status:** Accepted

## Decision

If recognition confidence is insufficient:

- Do nothing.

## Rationale
Executing the wrong command is more harmful than ignoring an uncertain tap.

---

# ADR-010 — Local Diagnostics

**Status:** Accepted

## Decision

Logs and diagnostics remain local unless explicitly exported by the user.

## Rationale

- Privacy
- User control
- Easier debugging

---

# ADR-011 — Background Operation

**Status:** Accepted

## Decision

Tapper shall function primarily as a lightweight background utility with minimal user interaction during normal operation.

---

# ADR-012 — Extensible Command Engine

**Status:** Accepted

## Decision

Support multiple execution providers behind a common abstraction.

Initial providers:

- Keyboard shortcuts
- AppleScript
- Apple Shortcuts
- Shell commands
- Executables

## Consequences

New providers can be added without modifying the recognition pipeline.

---

# ADR-013 — Calibration-Based Classification

**Status:** Accepted

## Decision

Classification relies on user calibration rather than predefined acoustic models.

## Rationale

Improves consistency across different devices and usage environments while preserving deterministic behavior.

---

# ADR-014 — Version 1 Scope Control

**Status:** Accepted

## Deferred Features

- Multi-tap gestures
- Application-specific profiles
- Plugin architecture
- Cross-platform support
- Adaptive deterministic threshold tuning
- Additional interaction zones

## Rationale

Maintain a focused and achievable Version 1.

---

# Decision Summary

| ADR | Topic | Status |
|-----|-------|--------|
| 001 | Offline-first | Accepted |
| 002 | Deterministic DSP | Accepted |
| 003 | Built-in microphone | Accepted |
| 004 | Four interaction zones | Accepted |
| 005 | Modular architecture | Accepted |
| 006 | Local storage | Accepted |
| 007 | Public APIs only | Accepted |
| 008 | Launch at Login | Accepted |
| 009 | Fail-safe execution | Accepted |
| 010 | Local diagnostics | Accepted |
| 011 | Background operation | Accepted |
| 012 | Extensible command engine | Accepted |
| 013 | Calibration-driven classification | Accepted |
| 014 | Controlled V1 scope | Accepted |

---

# End of Document
