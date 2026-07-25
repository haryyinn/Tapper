# Tapper — Hardware Validation Guide

Some acceptance criteria cannot be verified by automated tests in a development
environment: they depend on real acoustics, a real microphone, and real human
taps. This guide describes what remains to be measured on a physical MacBook and
how to do it.

Until these measurements exist, Tapper **must not** be described as meeting the
documented accuracy or sustained-CPU criteria.

---

## What is already verified (engineering verification)

These are covered by the automated suite and the benchmark harness, and need no
hardware:

| Area | Evidence |
|---|---|
| Pipeline mathematics (filter, FFT, features, Mahalanobis, Cholesky) | Unit tests + independent numerical verification |
| Behavioural baseline of the deterministic chain | `BehaviouralBaselineTests` (exact golden values) |
| Compute latency per stage and end-to-end | `./Scripts/benchmark.sh` |
| Bounded memory under sustained load | `StressAndReliabilityTests` |
| Documented failure and recovery paths | `StressAndReliabilityTests`, subsystem tests |
| Atomic persistence, corruption recovery | `ConfigurationTests` |

## What still requires a physical MacBook (hardware validation)

| Criterion | Source | Why it needs hardware |
|---|---|---|
| Prototype accuracy ≥ 80% | `TRD` NFR-003 | Requires real taps on a real chassis |
| Release accuracy ≥ 95%, per-zone ≥ 95% | `ALGORITHM` §24.5 | Same, across users and devices |
| False positives < 1% | `ALGORITHM` §24.6 | Requires real typing, speech, desk noise |
| False negatives < 5% | `ALGORITHM` §24.7 | Requires real taps of varying force |
| Sustained CPU (idle < 2%, recognition < 5%) | `ALGORITHM` §24.8 | Requires continuous live capture |
| End-to-end latency including capture | `TRD` NFR-002 | Benchmark measures compute only, not audio I/O |
| Sleep/wake, mic reconnect, permission changes | `TEST_PLAN` §11 | Requires real device state changes |
| Launch at login | `TEST_PLAN` §11 | Requires a signed, bundled app |

---

## Procedure

### 1. Build the app and baseline the machine

```bash
./Scripts/verify.sh
./Scripts/benchmark.sh
./Scripts/build-app.sh
```

Record the benchmark output — it establishes compute latency on that machine and
is the reference for any later tuning. `build-app.sh` produces
`build/Tapper.app`, an ad-hoc signed bundle; macOS attributes microphone and
Accessibility permissions to the bundle, so validation must run from it.

### 2. Grant microphone access

```bash
open build/Tapper.app
```

Use **Request Microphone Access**, then approve the prompt. The window also
shows the current state, microphone availability, and whether a calibration
profile is loaded.

### 3. Calibrate

```bash
build/Tapper.app/Contents/MacOS/Tapper --calibrate
```

The guided flow explains the procedure, names each zone, counts down before every
tap, and collects the documented 20 accepted samples per zone
(`ALGORITHM` §27.10). Rejected taps are retried automatically; the per-zone
summary reports how many retries were needed, which is the input to the
calibration success-rate target of ≥ 98% (`ALGORITHM` §24.5).

On success the profile is persisted and the runtime state is printed. Validation
is then usable with no further setup.

### 4. Measure accuracy and false positives

```bash
build/Tapper.app/Contents/MacOS/Tapper --validate --reps 25 --idle 300
```

The harness prompts for each tap, labels the expected zone automatically, and
records the detected zone, classification outcome, confidence, distance, and
latency — so no manual counting is required. The idle phase records
false-positive opportunities: during it, do **not** tap deliberately, but do
type, speak, use the trackpad, move the laptop, and connect the charger.

Results are written to `~/TapperValidation/` as CSV, JSON, and a report that
compares each measurement against its documented target. `--reps 100` gives a
stronger estimate; note that minimizing false positives takes priority over
sensitivity (`ALGORITHM` §24.6).

### 5. Measure sustained CPU and memory

With recognition running, sample CPU and memory in Activity Monitor or
`Instruments` over at least 10 minutes of idle listening, and again during
active tapping. Compare against `ALGORITHM` §24.8/§24.9.

### 6. Reliability

Exercise, and record the behaviour of, each `TEST_PLAN` §11 scenario: sleep and
wake, disconnecting/reconnecting the microphone, revoking and restoring
Accessibility permission, and restarting the application.

---

## Tuning after measurement

Only after real data exists may the provisional detection constants be tuned.
They are named and centralized in `Sources/Detection/DetectionConstants.swift`
and `Sources/Features/FeatureConstants.swift`:

| Constant | Current | Tune if |
|---|---|---|
| `detectionPeakThreshold` | 0.05 | Taps are missed (lower) or noise triggers detection (raise) |
| `minimumRMSEnergy` | 0.01 | Weak taps rejected (lower) or ambient noise accepted (raise) |
| `minimumSNR` | 2.0 | Detection fails in noisy rooms (lower) or noise passes (raise) |
| `minimumCandidateDurationMilliseconds` | 2 | Short taps rejected |
| `maximumCandidateDurationMilliseconds` | 25 | Real taps exceed it, or sustained sounds pass |
| `attackOnsetThreshold` / `decayOffsetThreshold` / `durationEnergyThreshold` | 0.10 | Temporal features poorly separate zones |
| `cooldownDuration` | 100 ms | Duplicate recognitions occur (raise, ≤ 500 ms) |

Change **one constant at a time**, re-run the accuracy measurement, and keep the
change only if it measurably improves the result. After any change, re-run:

```bash
./Scripts/verify.sh
```

The behavioural baseline tests will fail if a change alters the pipeline's
observable behaviour — that is expected when tuning a constant, and the baseline
should be updated deliberately, with the measurement that justified it recorded
in the commit message.
