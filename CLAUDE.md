# CLAUDE.md

> Primary Context Document for Claude Code
>
> Project: Tapper
> Platform: macOS (Apple Silicon)
> Language: Swift 6

---

# Read This First

Before making ANY code changes, read the following documents in order:

1. Docs/IMPLEMENTATION_RULES.md
2. Docs/AI_ENGINEERING_INSTRUCTIONS.md
3. Docs/TRD.md
4. Docs/ARCHITECTURE.md
5. Docs/ALGORITHM.md
6. Docs/API_REFERENCE.md
7. Docs/IMPLEMENTATION_PLAN.md
8. Docs/TEST_PLAN.md

Do not begin implementation until these documents have been understood.

---

# Project Overview

Tapper is a native macOS utility that recognizes taps on a MacBook chassis using the built-in microphone and executes user-configurable commands.

Version 1 goals:

- Offline-first
- Deterministic
- Zero AI
- Zero Machine Learning
- Local processing only
- Native Apple APIs
- Four interaction zones

---

# Core Philosophy

The implementation must remain:

- Deterministic
- Privacy-first
- Explainable
- Modular
- Lightweight
- Maintainable

When in doubt:

Choose the simpler deterministic solution.

---

# Non-Negotiable Constraints

Never introduce:

- AI
- Machine Learning
- CoreML
- TensorFlow
- PyTorch
- LLM APIs
- Cloud inference
- Analytics
- Telemetry
- Network-dependent recognition
- Private Apple APIs

Recognition must remain completely local.

---

# Runtime Pipeline

The runtime architecture SHALL remain:

User Tap

↓

Audio Acquisition

↓

Signal Processing

↓

Tap Detection

↓

Zone Classification

↓

Command Mapping

↓

Command Execution

Do not alter this pipeline.

---

# Module Ownership

Audio/
- Audio capture only.

DSP/
- Signal processing only.

Detection/
- Candidate tap detection only.

Classification/
- Zone recognition only.

Commands/
- Command execution only.

Configuration/
- Preferences and calibration.

Diagnostics/
- Logging and diagnostics.

System/
- Permissions and operating system integration.

No module may assume responsibilities outside its ownership.

---

# Current Version Scope

Version 1 supports:

✓ Four tap zones

✓ Local calibration

✓ Keyboard shortcuts

✓ AppleScript

✓ Shell commands

✓ Executables

✓ Apple Shortcuts

Not supported:

✗ Multi-tap gestures

✗ Plugins

✗ External microphones

✗ Cross-platform

✗ Application-specific mappings

These are future work.

---

# Engineering Priorities

Priority 1

Correctness

Priority 2

Determinism

Priority 3

Reliability

Priority 4

Performance

Priority 5

Maintainability

Never sacrifice correctness for cleverness.

---

# Performance Targets

Detection latency

≤100 ms

End-to-end latency

≤200 ms

No blocking on the audio thread.

No unnecessary allocations inside DSP loops.

---

# Coding Standards

Use:

- Swift 6
- SwiftUI
- AVFoundation
- Accelerate
- Core Audio
- Foundation
- OSLog

Prefer:

- value types
- immutable state
- dependency injection
- protocol abstractions where appropriate

Avoid:

- force unwraps
- force casts
- global mutable state
- unnecessary abstractions

---

# Testing

Every implementation must include:

- Unit tests
- Integration tests where applicable

Never merge code that breaks tests.

---

# Documentation

If implementation changes architecture or behavior:

STOP.

Update the documentation first.

Implementation must never silently diverge from the specification.

---

# Working Method

For every implementation request:

1. Understand the requirement.
2. Identify the affected modules.
3. Produce a short implementation plan.
4. Implement incrementally.
5. Add tests.
6. Verify architecture compliance.
7. Explain the changes made.

Do not implement multiple unrelated features simultaneously.

---

# Ambiguity Policy

If documentation is incomplete:

- Do not guess.
- State the ambiguity.
- Offer compliant alternatives.
- Wait for clarification before implementing.

---

# Definition of Success

A successful implementation:

✓ Builds successfully

✓ Passes all tests

✓ Matches the documentation

✓ Preserves architecture

✓ Introduces no undocumented behavior

✓ Meets latency targets

✓ Maintains deterministic recognition

---

# Repository Principle

The documentation is the specification.

The code is the implementation.

If they differ, the implementation is considered incorrect until both are synchronized.