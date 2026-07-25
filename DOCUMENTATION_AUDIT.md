# Tapper — Documentation Audit

Phase 9 includes a documentation review (`IMPLEMENTATION_PLAN` §6). This is an
**audit only**: nothing under `Docs/` has been modified. Every inconsistency,
ambiguity, and conflict found while implementing Phases 0–9 is recorded here so
the corrections can be made as a project-level decision.

Each finding states the conflict, how the implementation resolved it (via the
documentation precedence order), and what a documentation fix would look like.

Precedence used throughout: `IMPLEMENTATION_RULES` > `TRD` > `ARCHITECTURE` >
`ALGORITHM` > `API_REFERENCE` > `SYSTEM_DESIGN` > `DATA_MODELS` > ADRs, with
`DATA_MODELS` authoritative for data structures and `CALIBRATION` for the
calibration workflow.

---

## A. Direct conflicts between documents

### A1. Latency: <50 ms vs ≤200 ms
- **Conflict:** `ALGORITHM` §24.3 states end-to-end latency < 50 ms and §4.2
  sets a 50 ms recognition timeout. `TRD` NFR-002 and `IMPLEMENTATION_PLAN` §11
  state ≤ 200 ms (with ≤ 100 ms detection).
- **Resolved as:** TRD governs; ≤ 200 ms is binding. No 50 ms timeout is wired
  as a failing gate. Measured end-to-end compute is ~7 ms p95, so both figures
  are met in practice, but only ≤ 200 ms is enforced.
- **Fix:** reconcile §24.3/§4.2 with the TRD, or mark the §24.3 figures
  explicitly as aspirational sub-budgets.

### A2. Covariance: positive definite vs positive semi-definite
- **Conflict:** `ALGORITHM` §17.21 and `DATA_MODELS` §8.4 require positive
  **definite** (invertible); `CALIBRATION` §9.8 says positive **semi-definite**.
- **Resolved as:** positive definite, enforced by Cholesky and guaranteed by
  mandatory regularization Σ' = Σ + λI.
- **Fix:** correct `CALIBRATION` §9.8. Tracked as **BL-5**.

### A3. Preprocessing order
- **Conflict:** `ALGORITHM` §8 mandates DC removal → clipping detection →
  band-pass → normalization → windowing and forbids reordering.
  `DSP_PARAMETERS` §16 lists normalize before filter.
- **Resolved as:** `ALGORITHM` §8 order.
- **Fix:** correct `DSP_PARAMETERS` §16.

### A4. Feature ordering
- **Conflict:** `DSP_PARAMETERS` §8 swaps Spectral Bandwidth and Roll-off
  relative to `ALGORITHM` §15.4 / `DATA_MODELS` §6.6.
- **Resolved as:** the canonical §6.6 ordering (centroid, bandwidth, roll-off).
- **Fix:** correct `DSP_PARAMETERS` §8.

### A5. Cooldown default: 100 ms vs 200 ms
- **Conflict:** `ALGORITHM` §27.9 gives 100 ms; `DSP_PARAMETERS` §13 gives
  200 ms (range 100–500 ms, user adjustable).
- **Resolved as:** 100 ms default, configurable within 100–500 ms.
- **Fix:** align `DSP_PARAMETERS` §13.

### A6. Zero-crossing-rate units
- **Conflict:** `ALGORITHM` §14.10/§15.6 define crossings **per sample**;
  `DATA_MODELS` §6.5 `FeatureUnit` offers `crossingsPerSecond`.
- **Resolved as:** crossings per sample.
- **Fix:** align the `FeatureUnit` enum. (No code impact today — the atomic
  `Feature`/`FeatureUnit` models are not yet implemented; see D2.)

### A7. Command mapping model: `Action`/`ZoneMapping` vs `CommandBinding`
- **Conflict:** `DATA_MODELS` §2.5 and `CLAUDE_CONTEXT` §4 name `Action` and
  `ZoneMapping`; `DATA_MODELS` §12.4 defines `CommandBinding` and no `Action`.
- **Resolved as:** `CommandBinding` (§12 is authoritative for data structures).
- **Fix:** reconcile §2.5 and `CLAUDE_CONTEXT` §4. Tracked as **BL-10**.

### A8. `DiagnosticsSnapshot` ownership (unresolvable in code)
- **Conflict:** `DATA_MODELS` §11.9 assigns `DiagnosticsSnapshot` to
  Diagnostics; §10.8 assigns `EngineStatus` and `RuntimeStatistics`, which it
  aggregates, to Runtime. Runtime depends on Diagnostics for observational
  recording, so the reverse dependency would be circular.
- **Resolved as:** deferred; no ownership relocated, no shared module created,
  no provisional implementation. Tracked as **BL-11**.
- **Fix:** assign snapshot assembly explicitly — most naturally to Runtime —
  in `DATA_MODELS` §11.9.

---

## B. Internal contradictions within a single document

### B1. Peak Amplitude is degenerate as written
- **Issue:** `ALGORITHM` §14.4 defines Peak Amplitude as `max(|x[n]|)` of the
  *normalized* waveform, but §10.2 normalization forces that maximum to exactly
  1.0. As written the feature is a constant, contradicting its own stated
  purpose ("rejecting extremely weak events") and its 0–1 unit (§15.6). A
  constant feature also has zero variance, which would make the per-zone
  covariance singular without regularization.
- **Resolved as:** measured on the filtered signal immediately **before**
  normalization (the normalization divisor).
- **Fix:** state in §14.4 that Peak Amplitude is measured prior to
  normalization. Tracked as **BL-2**.

### B2. Sample retention vs dimensionality
- **Issue:** 20 samples/zone against a 10×10 covariance is statistically
  fragile, and a "maximum rejected = 10" rule could leave N = 10 for d = 10,
  yielding a singular matrix.
- **Resolved as:** minimum **retained** = 15 (well above d + 1 = 11), with the
  workflow requesting more samples below that; mandatory regularization
  guarantees invertibility.
- **Fix:** express the constraint as a minimum retained count. Tracked as
  **BL-6**.

---

## C. Ambiguities and undefined terms

### C1. Detection constants are named but never valued
- `ALGORITHM` §27.6 names Detection Threshold, Minimum RMS Energy, Minimum SNR,
  Peak Search Window, and Maximum Candidate Duration without giving values.
- **Resolved as:** provisional, named, configurable defaults (0.05, 0.01, 2.0,
  the analysis frame, 2–25 ms), documented as implementation defaults to be
  tuned against real measurements.
- **Fix:** record the tuned values in §27.6 once hardware validation completes.

### C2. Temporal-feature thresholds are undefined
- `ALGORITHM` §14.11–§14.13 define Attack/Decay/Signal Duration in words, but
  "signal onset", "ambient noise floor", and "adaptive noise threshold" are
  never quantified.
- **Resolved as:** three named constants, each defaulting to 0.10 of the
  normalized peak.
- **Fix:** specify the onset/offset/activity definitions in §14.

### C3. Noise-floor estimation method is unspecified
- `ALGORITHM` §19.17 requires continuous noise-floor monitoring but gives no
  method.
- **Resolved as:** EMA of frame RMS over non-candidate frames, smoothing 0.05.
- **Fix:** specify the estimator in §19.17.

### C4. "Spectral energy" is undefined
- `ALGORITHM` §14.8 defines roll-off via "85% of the spectral energy" without
  defining energy.
- **Resolved as:** cumulative Σ|X|² (the formal definition).
- **Fix:** state it explicitly. Tracked as **BL-3**.

### C5. "Destructive" shell commands are never defined
- `TRD` §9 requires confirmation before saving destructive shell commands but
  gives no classification rule.
- **Resolved as:** confirmation required for saving **every** shell-command
  binding — a conservative superset that invents no heuristic. Save-time only.
- **Fix:** either define "destructive" or restate the requirement as applying to
  all shell commands (which is what is implemented).

### C6. Per-type command `target` semantics are unspecified
- `DATA_MODELS` §12.3 defines `Command.target: String` without saying what it
  means per `CommandType`.
- **Resolved as:** documented per-type interpretation (shell command line,
  executable path, AppleScript source, shortcut name, shortcut combo string).
- **Fix:** record the per-type contract in §12.3.

### C7. Storage location, checksum algorithm, and schema version are unspecified
- `ARCHITECTURE` §200 says only "local configuration directory";
  `DATA_MODELS` §13.4 requires a `checksum` without naming an algorithm; §13.3
  requires a schema version without giving a value.
- **Resolved as:** `~/Library/Application Support/Tapper/`, SHA-256, `"1.0"`.
- **Fix:** record these in the documentation.

### C8. Ambiguity margin has no value
- `ALGORITHM` §18.10 / §27.8 require an ambiguity margin without specifying one.
- **Resolved as:** 0.5 Mahalanobis units, stored per zone.
- **Fix:** record the value; see also **BL-7** (relative vs absolute margin).

### C9. Automation permission cannot be queried without side effects
- `API_REFERENCE` §9 lists Automation as required, but macOS determines it
  per-target and probing can prompt the user.
- **Resolved as:** never probed at startup; reported as `notDetermined`, with
  denial surfacing through the AppleScript provider's failure path.
- **Fix:** note the per-target nature and the no-probe policy in §9.

---

## D. Specified but not implemented (with reasons)

### D1. `RecognitionResult` and Tap Quality
- `DATA_MODELS` §9.5 requires a `qualityScore` from the Tap Quality subsystem
  (`ALGORITHM` §20), which is unimplemented. The runtime therefore produces
  `ClassificationOutcome`. No quality value is synthesized. Tracked as **BL-8**.

### D2. Diagnostic/atomic models not yet needed
- `Feature`/`FeatureUnit`/`FeatureStatistics` (`DATA_MODELS` §6.3–§6.7),
  `FilteredSignal`/`DSPMetadata` (§5.8–§5.9), and `CalibrationReport` (§11.7)
  are not implemented: the classifier consumes `FeatureVector` directly, §5.8
  explicitly permits omitting `FilteredSignal`, and `CalibrationReport` depends
  on Tap Quality. Tracked as **BL-9**, **BL-11**.

### D3. GUI surface
- `PRD` lists "No GUI" in V1 scope while calibration requires an interactive UI.
  Per precedence, UI is in scope; the calibration engine is headless and
  drivable by a future UI. No UI has been built.
- **Fix:** confirm the intended V1 surface (expected: menu-bar app + calibration
  window) and correct the PRD.

---

## E. Documentation that matched implementation exactly

Recorded for balance — these needed no interpretation: the runtime state
machine and transition table (`ALGORITHM` §21), the execution decision sequence
(§18.16), the Mahalanobis and threshold mathematics (§17), the filter and FFT
parameters (§9, §13), the calibration workflow and state machine
(`CALIBRATION` §3–§9), atomic write requirements (§26.12), the permission matrix
(`API_REFERENCE` §9), and the persistence models (`DATA_MODELS` §13).

---

## Summary

| Category | Count |
|---|---|
| Direct conflicts between documents | 8 (A1–A8) |
| Internal contradictions | 2 (B1–B2) |
| Ambiguities / undefined values | 9 (C1–C9) |
| Specified but deferred | 3 (D1–D3) |

None of these blocked implementation: every one was resolved by the precedence
order or by an explicit, recorded project decision. All remain **documentation**
corrections, not implementation defects.
