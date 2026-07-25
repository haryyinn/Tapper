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
