# 07_TEST_PLAN.md

> **Tapper — Test Plan**
>
> Version: 1.0 (Draft)

---

# 1. Purpose

This document defines the verification and validation strategy for Tapper Version 1. It specifies the testing approach, environments, test categories, acceptance criteria, and representative test cases required to demonstrate compliance with the Technical Requirements Document (TRD).

---

# 2. Objectives

The test plan ensures that:

- Functional requirements are satisfied.
- Non-functional targets are achieved.
- False positives are minimized.
- The application behaves deterministically.
- Performance and stability meet release criteria.

---

# 3. Test Environment

## Hardware

- Apple Silicon MacBook (primary development platform)

## Operating System

- macOS 14+

## Build

- Debug
- Release

## Tools

- XCTest
- Instruments
- Console / OSLog
- Xcode

---

# 4. Test Categories

| Category | Purpose |
|----------|---------|
| Unit Testing | Validate individual components |
| Integration Testing | Validate subsystem interactions |
| Functional Testing | Verify requirements |
| Performance Testing | Measure latency and resource usage |
| Regression Testing | Prevent reintroduction of defects |
| Usability Testing | Validate user workflows |
| Stress Testing | Verify stability under load |

---

# 5. Unit Tests

## Audio Acquisition

- Initialize audio engine
- Detect microphone
- Recover after microphone loss
- Handle invalid buffers

## Signal Processing

- Normalize samples
- Remove DC offset
- Filter expected frequencies
- Window generation
- Feature extraction

## Tap Detection

- Detect valid tap
- Reject typing
- Reject trackpad click
- Reject charger insertion
- Reject lid closure

## Zone Classification

- Classify all four zones
- Reject ambiguous inputs
- Use calibration profile correctly

## Command Execution

- Execute keyboard shortcut
- Execute AppleScript
- Execute shell command
- Handle execution failures

---

# 6. Integration Tests

Pipeline Tests

1. Audio → DSP
2. DSP → Tap Detection
3. Detection → Classification
4. Classification → Command Mapping
5. Command Mapping → Execution

Success Criteria

- No dropped events
- Correct data transfer
- Stable execution

---

# 7. Functional Test Cases

| Test ID | Description | Expected Result |
|----------|-------------|-----------------|
| FT-001 | Finger tap (Top Left) | Correct command executes |
| FT-002 | Finger tap (Top Right) | Correct command executes |
| FT-003 | Finger tap (Bottom Left) | Correct command executes |
| FT-004 | Finger tap (Bottom Right) | Correct command executes |
| FT-005 | Typing | No command |
| FT-006 | Trackpad click | No command |
| FT-007 | Charger insertion | No command |
| FT-008 | Laptop movement | No command |
| FT-009 | Missing calibration | Recalibration requested |
| FT-010 | Permission revoked | Execution disabled |

---

# 8. Calibration Tests

- Initial calibration
- Recalibration
- Calibration persistence
- Invalid calibration data
- Device restart after calibration

Expected Result

Calibration remains valid until explicitly replaced.

---

# 9. Performance Tests

| Metric | Target |
|--------|--------|
| Tap Detection | ≤100 ms |
| End-to-End | ≤200 ms |
| Startup | <3 s |
| Memory Growth | Stable |
| CPU Usage | Acceptable sustained load |

---

# 10. Stress Tests

Scenarios

- Continuous tapping
- Rapid successive taps
- Long-running background execution
- Repeated configuration updates
- Continuous logging

Expected Result

No crashes or memory leaks.

---

# 11. Reliability Tests

- Launch at login
- Sleep / wake cycle
- Microphone reconnect
- Accessibility permission changes
- Application restart

---

# 12. Error Handling Tests

| Scenario | Expected Behaviour |
|----------|--------------------|
| Microphone unavailable | Recognition pauses |
| Invalid configuration | Defaults restored |
| Corrupt calibration | Recalibration requested |
| Command failure | Error logged |

---

# 13. Regression Testing

Regression tests shall be executed before every release.

Required Areas

- Recognition accuracy
- Latency
- Calibration
- Command execution
- Diagnostics

---

# 14. Acceptance Testing

Release Candidate Checklist

- All critical functional requirements pass.
- No critical defects.
- Performance targets achieved.
- Stability verified.
- Documentation complete.

---

# 15. Requirement Coverage

Each TRD requirement shall map to one or more tests.

Example

| Requirement | Test Cases |
|-------------|------------|
| FR-AA-* | UT-AA-*, IT-001 |
| FR-SP-* | UT-SP-* |
| FR-TD-* | FT-001–FT-010 |
| FR-ZC-* | Calibration Tests |
| FR-CE-* | Command Execution Tests |
| NFR-* | Performance Tests |

---

# 16. Exit Criteria

Testing is complete when:

- 100% of critical requirements verified.
- No open critical defects.
- No known reproducible crashes.
- Latency requirements satisfied.
- Accuracy targets achieved.

---

# 17. Deliverables

Testing produces:

- Test reports
- Performance reports
- Bug reports
- Coverage reports
- Release validation checklist

---

# End of Document
