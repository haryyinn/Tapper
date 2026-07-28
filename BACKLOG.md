# Tapper — Backlog

Implementation tasks intentionally kept out of current-phase scope. These are
**not** specification changes; the `Docs/` set remains authoritative. Each item
records what to build, the governing rationale, and acceptance criteria.

## Audio

### BL-1 — Validate capture format against the V1 contract (fail safe)

- **Status:** Open (future — not scheduled into a phase yet).
- **Origin:** Phase 1 review.
- **What:** Add explicit runtime validation that the format delivered by the
  input node matches the documented V1 capture contract — 48 kHz, mono (1
  channel), 32-bit float PCM (`ALGORITHM` §7.2 / §27.4).
- **Behavior on mismatch:** the Audio subsystem shall fail gracefully with an
  appropriate capability/configuration error and deliver no samples, rather than
  continuing on an unsupported format (`IMPLEMENTATION_RULES` §Error Handling —
  "on uncertainty, do nothing"). **Sample-rate conversion / resampling is out of
  scope**: the specifications do not define conversion behavior, so implementing
  it would be speculative.
- **Current behavior (Phase 1):** capture uses the input node's native format and
  assumes it matches the contract. The actual format is observable via
  `AVAudioEngineCaptureSource.currentMetadata()` but is not enforced; there is no
  comparison against 48 kHz and no error path for a mismatch.
- **Acceptance:** starting capture on a non-conforming format returns/raises a
  clear capability/configuration error and delivers no samples; conforming
  formats are unaffected.

## Documentation

### BL-2 — Clarify that Peak Amplitude is measured before normalization

- **Status:** Open (documentation task — no code change required).
- **Origin:** Phase 2, commit 4.
- **What:** `ALGORITHM` §14.4 defines Peak Amplitude as `max(|x[n]|)` of the
  *normalized* waveform. Because peak normalization (§10.2) forces that maximum
  to a constant 1.0, the formula is degenerate and contradicts the feature's own
  stated purpose (rejecting weak events) and its "Normalized (0–1)" unit (§15.6).
- **Resolution in code:** per project decision, Peak Amplitude is measured as
  `max(|x|)` of the filtered signal **immediately before** normalization (the
  normalization divisor). This is documented inline in
  `TimeDomainFeatures.peakAmplitude`.
- **Action:** update `ALGORITHM` §14.4 to state that Peak Amplitude is measured
  prior to normalization, keeping the public feature name "Peak Amplitude".

### BL-3 — Clarify the meaning of "spectral energy" in Spectral Roll-off

- **Status:** Open (documentation task — no code change required).
- **Origin:** Phase 2 review (approved).
- **What:** `ALGORITHM` §14.8 defines Spectral Roll-off via "85% of the spectral
  energy" without defining "energy". The implementation uses cumulative spectral
  energy Σ|X|² (the formal definition of energy), documented inline in
  `SpectralFeatures.spectralRollOff`.
- **Action:** update `ALGORITHM` §14.8 to state explicitly that spectral energy
  means the sum of squared magnitudes. The implementation is the approved
  interpretation and shall not change as part of this cleanup.

## Detection

### BL-4 — Double-impulse rejection (deferred, optional per specification)

- **Status:** Open (future — candidate for Phase 9 tuning).
- **Origin:** Phase 3 plan (approved).
- **What:** `ALGORITHM` §19.15 states that a candidate window containing
  multiple dominant peaks "**may** be rejected as ambiguous" — the behavior is
  optional and the peak-multiplicity method is unspecified. Phase 3 defers it:
  no double-impulse detector is implemented, which is spec-compliant.
- **Action:** during Phase 9 empirical validation, decide whether double-impulse
  rejection measurably reduces false positives; if adopted, specify the
  peak-multiplicity rule as a named configurable constant and update the docs.

## Calibration

### BL-5 — Reconcile positive-definite vs positive-semi-definite covariance

- **Status:** Open (documentation task — no code change required).
- **Origin:** Phase 4 plan (approved).
- **What:** `CALIBRATION` §9.8 lists the covariance requirement as "positive
  **semi-definite**", contradicting `ALGORITHM` §17.21 and `DATA_MODELS` §8.4,
  which require positive **definite** (invertible). Per precedence, positive
  definite governs; the implementation enforces it via Cholesky, guaranteed by
  mandatory regularization Σ' = Σ + λI.
- **Action:** update `CALIBRATION` §9.8 to say positive definite.

### BL-6 — Reconcile retention floor with "Maximum Rejected Samples"

- **Status:** Open (documentation task — no code change required).
- **Origin:** Phase 4 plan (approved).
- **What:** A "maximum rejected samples = 10" against 20/zone could leave N = 10
  for d = 10, yielding a singular covariance. The approved implementation uses a
  **minimum retained = 15** floor (well above d + 1 = 11); more rejections cause
  the calibration workflow to request additional samples.
- **Action:** update the calibration docs to express the constraint as a minimum
  retained count (≥ 15) rather than a maximum rejected count.

### BL-7 — Relative ambiguity metric investigation

- **Status:** Open (future — Phase 9 tuning).
- **Origin:** Phase 4 plan (approved).
- **What:** Version 1 uses an absolute ambiguity margin (best-vs-second-best
  Mahalanobis separation, default 0.5, `ALGORITHM` §18.10). A relative or
  ratio-based margin may generalize better across zones/users.
- **Action:** during Phase 9, evaluate relative ambiguity metrics; adopt only
  with a spec update. The implementation keeps the documented absolute margin.

## Classification / Runtime

### BL-8 — Assemble RecognitionResult (needs Tap Quality §20)

- **Status:** Open (blocked on Tap Quality subsystem).
- **Origin:** Phase 4 (approved decision).
- **What:** The canonical `RecognitionResult` (`DATA_MODELS` §9.5) requires a
  `qualityScore` produced by the Tap Quality subsystem (`ALGORITHM` §20), which
  is outside Phase 4 scope. Phase 4's classifier therefore produces
  `ClassificationOutcome` (zone, status, Mahalanobis distance, confidence 0–100,
  acceptance threshold, ambiguity info, timestamp) — every value it can
  determine — but not a synthesized quality score.
- **Action:** when Tap Quality (§20) is implemented, have the runtime/application
  layer assemble `RecognitionResult` from the `ClassificationOutcome`, the tap
  quality score, and the cooldown decision. Do **not** derive quality or a
  `QualityRating` from confidence (undocumented behavior). `ClassificationResult`
  / `ConfidenceModel` / `QualityRating` are introduced only if/when the docs
  require them.

### BL-9 — Reconcile CalibrationProfile / metadata / CalibrationSample models

- **Status:** Open (documentation task).
- **Origin:** Phase 4, commit 5.
- **What:** The implemented `CalibrationProfile` adds `normalization` and
  `configuration` (holding λ) — required by approved decisions and consistent
  with §7.6's stated responsibility ("provide runtime configuration for
  recognition") — but the canonical `DATA_MODELS` §7.6 struct does not list them.
  `CalibrationMetadata` §7.7 (`averageQuality`) and `CalibrationSample` §7.3
  (`qualityScore`) both depend on the Tap Quality subsystem (§20) and are not
  implemented in Phase 4 (no quality synthesized); the headless session works
  with validated feature vectors directly.
- **Action:** update `DATA_MODELS` §7.6 to include the normalization transform and
  configuration; introduce `CalibrationMetadata` / `CalibrationSample` (with their
  quality fields) when the Tap Quality subsystem (§20) is implemented.

## Commands / Configuration

### BL-10 — Reconcile Action / ZoneMapping with CommandBinding

- **Status:** Open (documentation task — no code change required).
- **Origin:** Phase 5 review.
- **What:** `DATA_MODELS` §2.5 lists `Action` and `ZoneMapping` among the Command
  Models (and `CLAUDE_CONTEXT` §4 repeats them as the `Commands/` module's owned
  types), but `DATA_MODELS` §12 — authoritative for data structures — defines
  `CommandBinding` as the canonical zone→command mapping and defines no `Action`
  type. Phase 5 follows §12.
- **Action:** reconcile the documentation so exactly one authoritative
  command-mapping model exists: update `DATA_MODELS` §2.5 (and `CLAUDE_CONTEXT`
  §4) to name `CommandBinding`, or specify `Action`/`ZoneMapping` in §12 if they
  are genuinely distinct concepts. Phase 6 implements `CommandBinding` per §12.

## Diagnostics

### BL-11 — Diagnostics models deferred until Runtime / Tap Quality exist

- **Status:** Open (blocked on owning subsystems).
- **Origin:** Phase 7 review.
- **What:** `DATA_MODELS` defines two diagnostics models that Phase 7 does not
  implement, because each depends on values owned by later subsystems:
  - `CalibrationReport` (§11.7) requires `averageQuality`, produced by the Tap
    Quality subsystem (`ALGORITHM` §20).
  - `DiagnosticsSnapshot` (§11.8) aggregates `EngineStatus` (§10.4) and
    `RuntimeStatistics` (§10.6), both owned by the Runtime subsystem (§10).
- **Constraint:** do **not** introduce placeholder values, provisional models, or
  synthesized quality scores to make these types exist earlier.
- **Action:** implement each model only once its owning subsystem exists —
  `DiagnosticsSnapshot` when the ownership conflict below is resolved in the
  documentation, and `CalibrationReport` when Tap Quality (§20) provides quality
  scores. Related: [[BL-8]] (RecognitionResult assembly), [[BL-9]] (calibration
  model reconciliation).

#### DiagnosticsSnapshot — unresolved ownership (documentation inconsistency)

Phase 8 supplied the data `DiagnosticsSnapshot` needs, but the model remains
**deferred because the documentation assigns its parts to two subsystems whose
dependency direction is fixed**:

- `DATA_MODELS` §11.9 assigns `DiagnosticsSnapshot` to the **Diagnostics**
  subsystem.
- `DATA_MODELS` §10.8 assigns `EngineStatus` and `RuntimeStatistics`, which the
  snapshot aggregates, to the **Runtime** subsystem.
- Runtime depends on Diagnostics for observational recording, so Diagnostics
  cannot depend on Runtime without creating a circular dependency.

This is a **documentation inconsistency, not an implementation deficiency**. Per
project decision, no workaround or provisional implementation is introduced: no
ownership is relocated, no shared module is created solely to break the cycle,
Runtime's dependency on Diagnostics stays limited to the existing observational
interface, and Diagnostics does not depend on Runtime.

- **Action:** resolve ownership explicitly in the architecture documentation
  (for example, by assigning `DiagnosticsSnapshot` assembly to Runtime in
  `DATA_MODELS` §11.9), then implement it to match. Until then it stays deferred.

## Audio (Phase 9 measurement)

### BL-12 — Lock-free ring buffer: not justified by measurement (T1)

- **Status:** Open (deferred on evidence; re-evaluate on hardware).
- **Origin:** Phase 9 performance baseline.
- **Background:** `RollingAudioBuffer.write` takes an `OSAllocatedUnfairLock`, so
  in principle the real-time audio thread can block — which
  `IMPLEMENTATION_RULES` §Threading forbids ("the audio capture thread SHALL
  NEVER block"). The lock was an approved simplicity decision with a lock-free
  redesign held in reserve.
- **Measurement** (`./Scripts/benchmark.sh`, 10-core Apple Silicon):
  - uncontended write: mean 0.005 ms, max 0.105 ms
  - contended write, **realistic** reader (one analysis window per 20 ms hop,
    matching the runtime): mean 0.005 ms, max **0.079 ms**
  - contended write, **pathological** reader (spinning with no pause): max
    **1383 ms**
  - audio callback budget: 256 frames @ 48 kHz = **5.33 ms**
- **Conclusion:** at the runtime's actual read cadence the write path stays ~68×
  below the callback budget, so the lock does **not** materially affect the
  documented performance or threading requirements. Per project decision the
  lock-free redesign is **not** implemented: an optimization must demonstrate
  measurable benefit, and there is none to demonstrate here.
- **Residual risk (honest):** the pathological result shows the lock *can* block
  the audio thread for an unbounded time under sufficient contention. This is a
  latent risk rather than an observed problem, and it is unmeasured on real
  hardware with a live audio callback.
- **Action:** re-run the contention measurement during hardware validation (see
  `VALIDATION.md`). If live capture shows write stalls approaching the 5.33 ms
  callback budget, implement the lock-free single-producer/single-consumer ring
  and prove behavioural equivalence against the baseline tests.

## Configuration (Phase 9 / calibration integration)

### BL-13 — Persisted timestamps lose sub-second precision

- **Status:** Open (minor; no effect on recognition).
- **Origin:** Guided calibration integration.
- **What:** `CalibrationProfile.createdAt` does not survive a persistence
  round-trip exactly: ISO-8601 encoding writes whole seconds, so
  `1785003272.300838` reloads as `1785003272.0`. `DATA_MODELS` §14.7 mandates
  ISO-8601 for dates while §13.12 says serialization "shall preserve numerical
  precision"; the two are in mild tension for timestamps.
- **Verified impact:** none on behaviour. A field-by-field comparison confirmed
  that mean vectors, covariance matrices, inverse covariances, thresholds, and
  the normalization transform are **bit-identical** across the round-trip. Only
  the metadata timestamp differs, and no recognition decision reads it.
- **Action:** decide whether ISO-8601 with fractional seconds should be
  specified for timestamps, or whether whole-second precision is intended.
  Documentation decision; the implementation follows the documented format and
  is not changed unilaterally.

## Recognition (ADR-015 / Track B)

### BL-14 — §17.23.7 does not say which ambiguity margin k-NN uses

- **Status:** Open (documentation decision; blocks nothing).
- **Origin:** k-NN recogniser implementation.
- **What:** `ALGORITHM` §17.23.7 requires the winning zone's vote weight to
  exceed the runner-up's "by at least the configured ambiguity margin,
  expressed as a fraction of the total weight". It does not say whether this is
  the profile's existing `ThresholdModel.ambiguityMargin` or a new constant.
  The two carry incompatible units: the profile's value is an absolute
  Mahalanobis distance difference (0.5, per the Phase 4 decision), whereas the
  k-NN margin is a dimensionless share of vote weight.
- **Current implementation:** `NearestNeighbourConstants.voteMargin = 0.10`, a
  separate constant, so no value is reused across units. It is an explicit
  parameter of the classifier and is recorded in every comparison result and in
  the validation CSV, so any figure can be traced back.
- **Action:** confirm the intended source and value. 0.10 was chosen as a
  permissive starting point that rejects only near-ties; it has no empirical
  basis yet and should be set from validation evidence, not preference.

### BL-15 — Report and summary logic has no automated test coverage

- **Status:** Open.
- **Origin:** Dual-recogniser reporting.
- **What:** `ValidationSession.swift` (summaries, confusion matrices, the
  recogniser-comparison section, CSV export) lives in the `TapperApp`
  executable target, which has no test target, so none of it is covered by
  XCTest. It was verified by compiling the real source against a synthetic run
  with hand-checked counts, but that check is not part of CI.
- **Why it matters:** a latent crash was found this way — a Swift `String`
  passed to a `%s` conversion, which reads it as a C string pointer. Formatting
  in this file is now done with padding helpers rather than `%s` for
  string columns, but nothing prevents the pattern returning.
- **Action:** extract the pure reporting types into a testable library target,
  or add a test target able to import the app module.
