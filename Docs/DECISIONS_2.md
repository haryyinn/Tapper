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

---

# ADR-015 — Labelled Sample Profiles and Dual Recognisers

**Status:** Accepted

## Context

Version 1 represents each interaction zone by a mean vector, a covariance
matrix, and an acceptance threshold, and classifies with Mahalanobis distance
(ADR-013, `ALGORITHM` §17). Hardware validation exposed three limitations of
that representation:

1. **Under-determined statistics.** A 10×10 covariance has 55 free parameters
   per zone. With 20 samples per zone the engine estimates 220 parameters from
   80 observations, which is why mandatory diagonal loading (λ = 1e-3) is
   required for the matrices to remain invertible at all.

2. **Unimodality assumption.** A single Gaussian per zone cannot represent a
   user who taps one zone in more than one way; the two modes average into a
   centroid that represents neither.

3. **Irreversible data loss.** Calibration discards the observations after
   computing statistics. Mean and covariance can always be recomputed from
   stored samples; the samples cannot be recovered from the statistics. This
   also prevents offline re-analysis of real calibration data.

Separately, and importantly, this decision does **not** address calibration
retries. Taps that are not detected or are rejected during validation fail in
the Detection subsystem, before any recogniser is invoked. That is tracked as
independent work.

## Decision

1. The calibration profile shall additionally persist **every accepted
   feature vector together with its zone label**. Existing statistics are
   retained, not replaced.

2. Two recognisers shall exist concurrently:
   - **Mahalanobis** — the Version 1 recogniser, unchanged and still available.
   - **Distance-weighted k-nearest-neighbour** — operating on the stored
     labelled samples.

3. Neither is declared the default on the strength of argument. Validation runs
   both recognisers on identical trials and reports agreement and disagreement.
   A default shall be chosen only from empirical hardware data.

4. k-NN shall apply an explicit rejection policy so that it can answer
   "unknown". Raw nearest-neighbour classification always returns a class,
   which would violate the fail-safe principle (ADR-009).

## Rationale

k-NN was selected as the second recogniser for reasons specific to Tapper:

- it estimates **no** parameters, so 20 samples per zone is not a statistical
  liability;
- it represents **multi-modal** zones natively;
- new samples are appended in constant time, which is the prerequisite for any
  future incremental learning;
- its decisions are directly explainable — the contributing neighbours can be
  named in a report.

Linear discriminant analysis was the main alternative and is more
statistically efficient (one pooled covariance, 55 parameters from 80 samples).
It was not chosen because it shares the unimodality assumption, cannot be
updated incrementally without a refit, and is less explainable. Storing raw
samples keeps LDA available for future evaluation without further migration.

## Consequences

- The profile schema gains a version; profiles without stored samples remain
  loadable and usable with Mahalanobis, and report k-NN as unavailable rather
  than failing silently.
- Profile size grows by roughly 80 × 10 doubles, which is negligible.
- Two recognisers must be maintained during the comparison period.
- Recognition remains deterministic, on-device, and free of any ML framework.


---

# ADR-016 — Recogniser Benchmark Framework and Offline Dataset Inspection

**Status:** Accepted
**Supersedes:** none
**Amends:** ADR-015

## Context

ADR-015 introduced a second recogniser and had validation run both on identical
trials, so that the choice between them could be made from measurement. Two
gaps remained.

First, the comparison was hard-coded to exactly two recognisers. Deciding which
recogniser is best requires evaluating more than two, and the candidates worth
evaluating are all cheap: they share the same stored samples and differ only in
how they turn distances into a decision. A framework that admits *n* recognisers
costs little and removes the temptation to argue about candidates that were
never measured.

Second, the acceptance radius of §17.23.6 is an analytical choice — `mean + k·σ`
of the leave-one-out nearest-neighbour distances — made because it mirrors the
existing threshold formulation, not because it was measured. Whether it is
appropriate cannot be determined without recording, for every real tap, both the
distance observed and the radius it was tested against.

Separately, storing every labelled sample (ADR-015) turned the calibration
profile into a dataset. A dataset that cannot be inspected is of limited use:
questions such as "do these zones overlap?" and "is this tap an outlier or a
different cluster?" are geometric, and answering them from summary statistics
is exactly the indirection ADR-015 set out to remove.

## Decision

### 1. The production recogniser does not change

Mahalanobis remains the recogniser wired to command execution. No benchmark
result promotes a recogniser automatically. Promotion is a separate, explicit
decision taken on hardware evidence.

### 2. Recognisers become a uniform, enumerable abstraction

A recogniser is any deterministic mapping from a feature vector to a
classification outcome, given a calibration profile. Validation evaluates a set
of them on the identical normalized feature vector and reports each one's
metrics side by side.

The Version 1 benchmark set is:

| Identifier | Description |
|---|---|
| `mahalanobis` | The production recogniser (§17.13). |
| `nearest-centroid` | Euclidean distance to each zone mean (§17.24). |
| `knn-1` | Nearest neighbour, k = 1 (§17.23). |
| `knn-3-weighted` | Distance-weighted k-NN, k = 3 (§17.23). |
| `knn-5-weighted` | Distance-weighted k-NN, k = 5 (§17.23). |

Recognisers are constructed against a profile once and then classify many
vectors, so that measured latency reflects classification and not
model preparation. Without this, a recogniser that derives its model per call
would be reported as slower for a reason unrelated to its merits.

### 3. The acceptance radius is instrumented, not replaced

The formula of §17.23.6 is unchanged. Every evaluated tap records the distance
observed, the radius it was tested against, their difference, whether the tap
was accepted, and the resulting confidence. This is measurement infrastructure
for a later decision; it changes no threshold.

### 4. Validation exports feature vectors

Each trial records the normalized feature vector that produced it. Without it,
an unknown or misclassified tap cannot be located in feature space, and the
dataset cannot be inspected against the calibration samples it failed to match.

### 5. Dataset inspection is an offline developer tool

Feature-space inspection is provided as a separate executable, not as part of
the application. It reads a calibration profile and, optionally, a validation
run, and writes a static report. It is never present in the shipped bundle,
performs no capture, and cannot modify a profile.

Projection uses **principal component analysis**. t-SNE and UMAP were
considered and rejected: both are stochastic, both are sensitive to
hyperparameters whose defaults would themselves become unexamined heuristics,
neither preserves global distances — which is precisely the property under
investigation — and both would require a dependency the project does not have.
PCA is deterministic, has no hyperparameters, is implementable with the linear
algebra already present, and the variance it fails to capture is reportable, so
its own inadequacy is visible rather than hidden.

## Consequences

- The benchmark set grows the validation report and the exported schema. Both
  are developer-facing artefacts, so the cost is acceptable.
- Five recognisers run per candidate instead of two. All are O(samples) over a
  dataset of roughly 80 vectors, and the cost falls outside the audio callback.
- Nothing in this ADR changes detection, and nothing changes what the
  application does at runtime with a recognised tap.
- The projection tool can mislead if a two-dimensional view is read as the
  space the recogniser sees. Reports state the captured variance so that a
  low-fidelity projection is identifiable as such.
