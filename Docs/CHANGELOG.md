# 09_CHANGELOG.md

> **Tapper — Changelog**
>
> This project follows Semantic Versioning (SemVer) and the principles of *Keep a Changelog*.

---

# Changelog

All notable changes to this project will be documented in this file.

The format is based on:

- Keep a Changelog
- Semantic Versioning (SemVer)

---

# [Unreleased]

## Added

- Placeholder for upcoming features.

## Changed

- Placeholder for modifications.

## Fixed

- Placeholder for bug fixes.

## Removed

- Placeholder for removed functionality.

---

# [1.0.0] - Initial Release

## Added

### Core Recognition

- Deterministic tap recognition engine
- Four interaction zones
    - Top Left
    - Top Right
    - Bottom Left
    - Bottom Right
- Calibration workflow
- Local recognition pipeline

### Signal Processing

- Audio acquisition
- Rolling audio buffer
- DSP preprocessing
- Feature extraction
- Peak detection
- Candidate validation
- Zone classification

### Command Execution

- Keyboard shortcut execution
- AppleScript execution
- Shell command execution
- Executable launching
- Apple Shortcuts integration

### Configuration

- Local preferences
- Calibration storage
- Command mappings

### Diagnostics

- Structured logging
- Diagnostic bundle export
- Local log storage

### System Integration

- Accessibility support
- Launch at Login
- Notification support
- Permission management

### Documentation

- Product Requirements Document (PRD)
- Technical Requirements Document (TRD)
- System Design
- Architecture
- Algorithm Specification
- API Reference
- Implementation Plan
- Test Plan
- Architecture Decisions
- Changelog

---

## Security

- Offline-first processing
- Local-only storage
- Public macOS APIs only
- No cloud communication
- No machine learning
- No external services

---

## Performance

Target metrics

- Detection latency ≤100 ms
- End-to-end latency ≤200 ms
- Stable background execution
- Constant memory usage

---

# Versioning Policy

Tapper follows Semantic Versioning.

## Major Version (X.0.0)

Breaking architectural or behavioral changes.

Examples

- Recognition engine redesign
- Plugin architecture
- Cross-platform support

---

## Minor Version (1.X.0)

New backwards-compatible functionality.

Examples

- Additional command providers
- New calibration workflow
- Additional interaction modes

---

## Patch Version (1.0.X)

Bug fixes.

Examples

- Stability improvements
- Performance optimizations
- Documentation corrections

---

# Release Process

Before each release:

- All automated tests pass.
- No critical defects remain.
- Performance targets verified.
- Documentation updated.
- Version number incremented.
- Git tag created.

---

# Tag Naming Convention

Examples

v1.0.0

v1.1.0

v1.2.3

---

# Future Releases

## Version 1.1

Planned

- Multi-tap gestures
- Additional configuration options
- Improved diagnostics

---

## Version 1.2

Planned

- Application-specific profiles
- Expanded command providers

---

## Version 2.0

Potential roadmap

- Plugin architecture
- Additional interaction zones
- Cross-platform implementation

---

# End of Document
