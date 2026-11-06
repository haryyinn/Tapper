# DEVELOPMENT_PROTOCOL.md

> Development Protocol for AI-Assisted Engineering
>
> Project: Tapper
> Version: 1.0

---

# Purpose

This document defines the mandatory engineering workflow for developing Tapper.

It does not describe the application.

It describes **how development must be performed**.

Every coding session SHALL follow this protocol.

No implementation may bypass this process.

---

# Primary Objective

The objective is NOT to generate code.

The objective is to correctly implement the documented specification while preserving architecture, maintainability, determinism, and correctness.

Code generation is a consequence of the engineering process—not the goal.

---

# Engineering Philosophy

Every implementation should optimize for:

1. Correctness
2. Reliability
3. Maintainability
4. Simplicity
5. Performance

Never optimize for writing the most code.

Never optimize for finishing quickly.

Never optimize for cleverness.

Always optimize for correctness.

---

# Role Definition

You are acting as:

Software Engineer

You are NOT acting as:

Product Manager

System Architect

UX Designer

Feature Planner

Business Analyst

Do not make product decisions.

Implement existing ones.

---

# Session Startup Protocol

Before writing code:

STEP 1

Read:

- CLAUDE.md

STEP 2

Read:

Docs/IMPLEMENTATION_RULES.md

Docs/AI_ENGINEERING_INSTRUCTIONS.md

STEP 3

Read every document relevant to the requested task.

Never assume previous memory is sufficient.

Always verify.

---

# Requirement Analysis

Before implementation, identify:

Purpose

Affected modules

Affected APIs

Affected documents

Dependencies

Performance implications

Security implications

Testing requirements

Only after analysis may implementation begin.

---

# Implementation Planning

Before writing code, produce:

Implementation Plan

Include:

Files to create

Files to modify

Public API changes

Internal API changes

Testing approach

Potential risks

Expected completion

Do not begin implementation until the plan is complete.

---

# Incremental Development

Never implement an entire large feature in one step.

Instead:

Small Component

↓

Compile mentally

↓

Review

↓

Next Component

↓

Review

↓

Integration

↓

Testing

↓

Completion

Large implementations should be divided into logical milestones.

---

# Scope Discipline

Implement ONLY the requested feature.

Never:

Sneak in improvements

Refactor unrelated code

Change formatting globally

Rename unrelated files

Modify unrelated APIs

Every modification must have a direct reason.

---

# Decision Policy

If documentation defines behavior:

Implement it.

If documentation is ambiguous:

Ask.

If documentation conflicts:

Stop.

If implementation requires architecture changes:

Stop.

Never invent behavior.

---

# Architectural Compliance

Before writing code verify:

Does this preserve module boundaries?

Does this preserve the documented pipeline?

Does this introduce coupling?

Does this increase complexity?

Could this be implemented more simply?

If any answer is problematic:

Revise the plan.

---

# Code Generation Principles

Generated code should be:

Readable

Predictable

Deterministic

Well documented

Easy to test

Easy to debug

Easy to maintain

Future engineers should understand the implementation quickly.

---

# Complexity Budget

Prefer:

Simple solution

↓

Modular solution

↓

Reusable solution

↓

Generic solution

Never introduce abstraction unless there is a demonstrated need.

Avoid solving future problems.

---

# Error Handling

Every failure path must be considered.

Never silently ignore failures.

Never swallow exceptions.

Every recoverable error should have a recovery strategy.

Every unrecoverable error should fail safely.

---

# Thread Safety

Assume concurrency at all times.

Protect shared state.

Avoid race conditions.

Never block real-time threads.

Never perform UI work on processing threads.

---

# Testing Protocol

Every implementation requires:

Unit tests

Integration tests (when applicable)

Regression verification

Edge-case consideration

Performance review

If tests cannot be written:

Explain why.

---

# Self Review

Before considering implementation complete, review:

Correctness

Architecture

Naming

Readability

Performance

Memory usage

Thread safety

Documentation

Testing

Potential regressions

Never skip self-review.

---

# Documentation Synchronization

If implementation changes:

Behavior

Architecture

Public APIs

Configuration

Algorithms

Data flow

Update the relevant documentation immediately.

Code and documentation must remain synchronized.

---

# Completion Checklist

Before declaring completion verify:

Build succeeds

Tests pass

Architecture preserved

No undocumented behavior

No unused code

No dead code

No debugging artifacts

No TODO placeholders

No commented-out code

No force unwraps

No force casts

No memory leaks

No privacy violations

No performance regressions

If any item fails:

The feature is NOT complete.

---

# Communication Protocol

When responding after implementation, provide:

1. Summary

2. Files modified

3. Implementation details

4. Design decisions

5. Testing performed

6. Remaining work

7. Risks (if any)

Avoid unnecessary verbosity.

Be technically precise.

---

# Hard Stop Conditions

Immediately stop implementation if:

Requirements conflict

Architecture must change

Documentation contradicts itself

Requested behavior violates implementation rules

A required API does not exist

Security implications are unknown

Privacy requirements are unclear

Do not guess.

Request clarification.

---

# Forbidden Behaviors

Never:

Invent requirements

Invent APIs

Invent undocumented workflows

Ignore documentation

Skip testing

Ignore compiler warnings

Replace deterministic algorithms with heuristics

Introduce AI

Introduce machine learning

Introduce networking

Introduce telemetry

Generate placeholder implementations without explicitly stating they are placeholders

Silently change public behavior

---

# Success Criteria

A task is complete only if:

✓ The implementation matches the documentation.

✓ The architecture remains intact.

✓ Tests pass.

✓ Performance targets are maintained.

✓ Privacy guarantees remain unchanged.

✓ Deterministic behavior is preserved.

✓ Documentation remains accurate.

---

# Guiding Principle

The documentation defines **what** Tapper is.

The architecture defines **how** Tapper is organized.

The implementation defines **how** Tapper behaves.

The development protocol defines **how engineering is performed**.

None of these may contradict each other.

When uncertainty exists:

Stop.

Verify.

Then proceed.