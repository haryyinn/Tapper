# 11_IMPLEMENTATION_RULES.md

> Tapper — Implementation Rules
>
> Version: 1.0

---

# Purpose

This document defines the mandatory engineering rules governing the implementation of Tapper.

Every implementation MUST conform to these rules.

If any implementation conflicts with this document, this document takes precedence.

These rules are normative.

Keywords such as **MUST**, **MUST NOT**, **SHALL**, **SHALL NOT**, **SHOULD**, and **MAY** follow RFC 2119 semantics.

---

# Rule Hierarchy

When conflicts exist, documents shall be interpreted in the following order:

1. Implementation Rules
2. Technical Requirements (TRD)
3. Architecture
4. Algorithm
5. API Reference
6. System Design
7. PRD

No implementation may violate a higher-priority document.

---

# Architectural Integrity

The documented architecture is authoritative.

The implementation SHALL NOT:

- Merge independent subsystems.
- Introduce undocumented dependencies.
- Bypass subsystem interfaces.
- Remove architectural layers.
- Create circular dependencies.

Every subsystem SHALL have one clearly defined responsibility.

---

# Approved Pipeline

The runtime pipeline SHALL remain:

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

No additional recognition stages may be inserted without updating the architecture.

---

# Technology Restrictions

The implementation MUST use:

- Swift
- SwiftUI
- AVFoundation
- Core Audio
- Accelerate
- Foundation
- Core Graphics
- Accessibility APIs
- UserDefaults
- FileManager
- OSLog

Use of alternative frameworks requires documentation updates.

---

# Prohibited Technologies

The implementation SHALL NOT include:

- Artificial Intelligence
- Machine Learning
- Neural Networks
- TensorFlow
- PyTorch
- CoreML
- LLM APIs
- Cloud inference
- Remote recognition
- External recognition services

Recognition SHALL remain deterministic.

---

# Offline Requirement

Tapper SHALL operate without internet connectivity.

Recognition SHALL NOT depend upon:

- Cloud services
- Remote APIs
- WebSockets
- HTTP requests
- Analytics platforms

---

# Privacy Rules

Tapper SHALL NEVER:

Upload audio.

Upload calibration.

Upload diagnostics.

Upload logs.

Upload user preferences.

Transmit microphone data.

No telemetry shall exist.

---

# Audio Rules

Only the built-in microphone is supported in Version 1.

Audio SHALL:

exist only in memory during recognition.

NOT be persisted unless explicitly exported by the user.

NOT leave the device.

---

# Determinism

Given:

- identical calibration
- identical audio input
- identical configuration

the recognition result SHALL be identical.

No randomness is permitted.

No probabilistic algorithms are permitted.

---

# Threading Rules

The audio capture thread SHALL NEVER:

block

allocate excessive memory

perform UI work

perform command execution

perform file IO

perform network activity

Only lightweight DSP operations are permitted.

---

# Memory Rules

Avoid unnecessary allocations.

Reuse buffers.

Prefer stack allocation where appropriate.

Prevent retain cycles.

No memory leaks are acceptable.

---

# Performance Rules

Target latency:

Detection ≤100 ms

End-to-end ≤200 ms

Recognition SHALL execute in real time.

---

# Configuration Rules

All configuration SHALL remain local.

Configuration SHALL include:

Preferences

Calibration

Command mappings

Settings

Configuration SHALL be human-readable where practical.

---

# Logging Rules

Logging SHALL use OSLog.

Logs SHALL NOT contain:

Raw microphone data

Sensitive user information

Personally identifiable information

Passwords

Secrets

---

# Error Handling

The application SHALL fail safely.

When uncertainty exists:

DO NOTHING.

Incorrect command execution is considered worse than missed recognition.

---

# Command Execution

Supported:

Keyboard shortcuts

AppleScript

Apple Shortcuts

Executables

Shell commands

Execution SHALL occur only after successful recognition.

---

# Permissions

Required:

Microphone

Accessibility

Automation

Optional:

Notifications

The application SHALL degrade gracefully if permissions are denied.

---

# Coding Standards

Follow Swift API Design Guidelines.

Avoid force unwraps.

Avoid force casts.

Avoid global mutable state.

Prefer value types.

Prefer immutable data.

Document all public APIs.

---

# Dependency Management

Avoid unnecessary third-party dependencies.

Apple frameworks are preferred.

Every external dependency SHALL have documented justification.

---

# Testing Rules

Every new feature SHALL include:

Unit tests.

Integration tests.

Regression tests.

Performance validation where applicable.

No feature is complete without tests.

---

# Documentation Rules

Every architectural modification SHALL update:

Architecture

Algorithm

API Reference

Implementation Plan

Test Plan

Change Log

Documentation SHALL remain synchronized with implementation.

---

# Version Control

No direct commits to the release branch.

Meaningful commit messages are required.

Major architectural changes SHALL reference an Architecture Decision Record.

---

# Security Rules

No private Apple APIs.

No undocumented system calls.

No privilege escalation.

No execution outside documented permissions.

---

# Future Features

Deferred features SHALL NOT appear in Version 1 unless:

Architecture updated.

TRD updated.

Tests added.

Documentation approved.

---

# Source of Truth

If code contradicts documentation:

The documentation is correct.

The code SHALL be modified.

---

# Code Generation Instructions (For AI Coding Assistants)

When generating code:

DO:

- Follow every document in Docs/.
- Preserve module boundaries.
- Generate production-quality Swift.
- Prefer readability over cleverness.
- Write deterministic code.
- Add documentation comments.
- Add tests with new features.
- Keep functions focused and cohesive.
- Respect subsystem ownership.

DO NOT:

- Invent new architecture.
- Replace deterministic logic with heuristics.
- Introduce AI or ML.
- Skip tests.
- Skip error handling.
- Ignore documented constraints.
- Add hidden behavior.
- Change documented interfaces without updating the documentation.
- Introduce unnecessary abstractions.
- Add dependencies without justification.

If a requested implementation conflicts with these rules:

STOP.

Explain the conflict.

Do not generate violating code.

---

# Compliance

Every pull request SHALL satisfy:

✓ Builds successfully

✓ Tests pass

✓ No architecture violations

✓ No undocumented behavior

✓ No privacy violations

✓ No performance regressions

✓ Documentation updated

Only compliant implementations may be merged.

---

# End of Document