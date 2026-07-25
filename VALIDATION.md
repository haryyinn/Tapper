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

### 1. Baseline the machine

```bash
./Scripts/verify.sh
./Scripts/benchmark.sh
```

Record the benchmark output. It establishes compute latency on that machine and
is the reference for any later tuning.

### 2. Calibrate

Run calibration and collect the documented 20 accepted samples per zone
(`ALGORITHM` §27.10), tapping each zone the way it would be tapped in normal
use. Note how many attempts were rejected — the calibration success rate target
is ≥ 98% (`ALGORITHM` §24.5).

### 3. Measure accuracy

For each of the four zones, perform a counted series of deliberate taps (100 per
zone gives a usable estimate at this stage) and record:

- taps correctly recognized as that zone,
- taps recognized as a different zone,
- taps not recognized at all (false negatives).

Per-zone accuracy is `correct / total`. Overall accuracy is the total across all
four zones. Compare against ≥ 80% (prototype gate) before tuning anything.

### 4. Measure false positives

With recognition running and **no** deliberate taps, perform each of these for a
fixed interval (5 minutes each is adequate) and count any recognition:

- typing on the keyboard,
- normal speech near the machine,
- trackpad clicks,
- placing objects on the desk, moving the laptop,
- connecting and disconnecting the charger, closing the lid.

False positive rate is `recognitions / opportunities`; the target is < 1%
(`ALGORITHM` §24.6). Note that minimizing false positives takes priority over
sensitivity (§24.6).

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
