# 12_AI_ENGINEERING_INSTRUCTIONS.md

> **Tapper — AI Engineering Instructions**
>
> Version: 1.0

---

# Purpose

This document defines the mandatory operating instructions for any AI coding assistant (Claude Opus, Claude Code, Codex, GPT, etc.) working on the Tapper codebase.

These instructions govern **how code should be generated**, not the application's runtime behavior.

---

# Primary Objective

Your role is to implement the documented specification.

You are **not** the system architect or product designer.

The documentation under `Docs/` is the single source of truth.

Never replace documented decisions with your own assumptions.

---

# Source of Truth (Priority Order)

When implementing Tapper, use the following precedence:

1. `11_IMPLEMENTATION_RULES.md`
2. `01_TRD.md`
3. `03_ARCHITECTURE.md`
4. `04_ALGORITHM.md`
5. `05_API_REFERENCE.md`
6. `02_SYSTEM_DESIGN.md`
7. `06_IMPLEMENTATION_PLAN.md`
8. `07_TEST_PLAN.md`
9. `00_PRD.md`
10. Existing codebase

If two sources conflict, follow the higher-priority document.

---

# Your Responsibilities

You SHALL:

- Implement only documented functionality.
- Produce production-quality Swift code.
- Preserve the documented architecture.
- Keep implementations deterministic.
- Write maintainable code.
- Add tests for new functionality.
- Explain assumptions when documentation is incomplete.

You SHALL NOT:

- Redesign the application.
- Introduce undocumented features.
- Change public behavior without documentation updates.
- Ignore documented constraints.

---

# Architectural Rules

Never:

- Merge independent modules.
- Introduce circular dependencies.
- Skip layers in the pipeline.
- Bypass subsystem boundaries.
- Couple unrelated components.

Always preserve:

Audio Acquisition
→ Signal Processing
→ Tap Detection
→ Zone Classification
→ Command Mapping
→ Command Execution

---

# Code Generation Rules

Generate code that is:

- Correct
- Readable
- Deterministic
- Testable
- Modular
- Documented

Prefer clarity over cleverness.

Avoid unnecessary abstraction.

---

# Swift Standards

Use:

- Swift 6
- SwiftUI
- Structured Concurrency where appropriate
- Value types by default
- Protocol-oriented design where beneficial

Avoid:

- Force unwraps (!)
- Force casts (as!)
- Global mutable state
- Massive view models
- Excessively long functions

---

# Performance

Assume real-time audio processing.

Never:

- Block the audio thread
- Perform file I/O on the audio thread
- Perform UI updates on the audio thread
- Execute commands on the audio thread

Keep memory allocations minimal inside processing loops.

---

# Determinism

Never introduce:

- Random values
- Probabilistic algorithms
- Machine learning
- Adaptive AI models
- Hidden heuristics

The same calibrated input must always produce the same output.

---

# Privacy

Never generate code that:

- Uploads audio
- Sends telemetry
- Contacts external servers
- Stores microphone data unnecessarily
- Tracks users

Everything remains local unless explicitly documented otherwise.

---

# Dependencies

Do not add third-party libraries unless explicitly requested.

Prefer Apple frameworks.

If a new dependency appears necessary:

1. Explain why.
2. Identify alternatives.
3. Wait for approval before using it.

---

# Testing

Every feature should include:

- Unit tests
- Integration tests (where applicable)

When modifying existing code, update affected tests.

Never leave failing tests unresolved.

---

# Documentation

If implementation changes architecture or behavior:

Stop.

Identify the affected documents.

Explain what must change before continuing.

Do not silently diverge from the specification.

---

# Handling Ambiguity

If documentation is ambiguous:

1. State the ambiguity.
2. Offer the smallest compliant implementation.
3. Do not invent product decisions.

---

# Refactoring

Refactor only when it:

- Improves readability
- Improves maintainability
- Improves performance
- Removes duplication

Never refactor solely for stylistic preference.

---

# Error Handling

Prefer explicit errors over silent failures.

Recover safely where possible.

If recognition confidence is insufficient:

Do nothing.

---

# Output Format

When implementing a feature:

1. Brief implementation plan.
2. Files created or modified.
3. Swift code.
4. Tests.
5. Explanation of key decisions.
6. Remaining work (if any).

---

# Definition of Success

A successful implementation:

- Builds without errors.
- Passes tests.
- Matches the documented behavior.
- Preserves the architecture.
- Introduces no undocumented functionality.
- Meets performance targets.

---

# Hard Stop Conditions

Stop and ask for clarification if:

- Documentation conflicts.
- A requested feature contradicts the specification.
- A new architecture is required.
- A required API is unavailable.
- A proposed change violates implementation rules.

Never guess in these situations.

---

# End of Document
