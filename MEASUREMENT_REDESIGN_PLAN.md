# Measurement Redesign — Implementation Plan

Implements ADR-017. Split into phases so that **one variable changes at a time**.

| Phase | Question it answers | Feature dimension |
|---|---|---|
| **0** | What is the honest "before" number? | 10 (unchanged, defective) |
| **1** | Did fixing the *measurement* improve Tapper? | 10 (unchanged) |
| **2** | Do better *features* improve recognition further? | may increase |

---

## What "unchanged" means in Phase 1

This needs stating precisely, because two different things could be meant.

- **Feature dimension: unchanged.** Ten.
- **Feature identities: unchanged.** The same ten named physical quantities.
- **Feature values: all ten change.**

The third point is not a violation of the one-variable rule — it *is* the
variable. Five features (`rmsEnergy`, `zeroCrossingRate`, `spectralCentroid`,
`spectralBandwidth`, `spectralRollOff`) are whole-frame aggregates, so anchoring
the window changes their values even though their definitions are untouched.
Leaving them frame-aggregated would mean knowingly retaining contaminated
measurements, and would muddy Phase 1's hardware result with the very noise the
phase exists to remove.

So: **Phase 1 asks the same ten questions of the signal, correctly. Phase 2 asks
new questions.**

---

## Phase 0 — Fix the instrument before changing the system

The validation harness currently cannot measure the outcome trustworthily. Using
it to judge Phase 1 would repeat, at the level of the experiment, the error
ADR-017 corrects at the level of the signal.

**Two defects:**

1. **Pacing.** Reaction-time median 771 ms against a 1200 ms tap window, with
   only 68 of 100 trials registering any audio. Some taps land after the window
   closes, so part of the 90% miss rate measures the operator, not the system.
2. **Latency is not latency.** `TrialRecorder` records
   `timestamp.timeIntervalSince(windowStart)` — time since the window opened,
   dominated by reaction time — while the report labels it "Processing latency
   (frame → dispatch)". Trials with no candidate contribute 0.0, which is why
   the median reads 0.000 ms. The figure measures neither quantity.

**Work:** widen and/or adapt the tap window from observed reaction times; measure
processing latency from frame receipt to outcome; relabel. No detector constant,
no feature, no recogniser touched.

**Deliverable:** one hardware run producing a **trustworthy baseline** under the
current (defective) measurement. This is the denominator for Phase 1.

**Cost:** roughly ten minutes of tapping. Without it, "did it improve?" has no
reliable comparison point.

---

## Phase 1 — Measurement architecture

### Slot-by-slot mapping

| # | Feature | Today | Phase 1 |
|---|---|---|---|
| 0 | `peakAmplitude` | Correct | Same, over the event window |
| 1 | `rmsEnergy` | Energy ÷ *frame* | Energy ÷ *event window* |
| 2 | `spectralCentroid` | FFT of frame + taper | FFT of event window |
| 3 | `spectralBandwidth` | FFT of frame + taper | FFT of event window |
| 4 | `spectralRollOff` | FFT of frame + taper | FFT of event window |
| 5 | `dominantFrequency` | Robust | Same, over the event window |
| 6 | `zeroCrossingRate` | Crossings ÷ *frame* | Crossings ÷ *event window* |
| 7 | `attackTime` | Correct (0% alignment CV) | Same, from the localised onset |
| 8 | `decayTime` | Quarter-period of the dominant frequency | Event-aligned early-decay measurement |
| 9 | `signalDuration` | `min(physical, 40 ms − onset offset)` | Event-aligned duration via decay-rate estimation |

### Why decay-rate estimation is a measurement change, not a feature change

For an exponential decay, the −20 dB duration and the time constant are related
by a constant:

```
T20 = τ · ln(10)
```

Reporting `τ · ln(10)` is therefore *the same physical quantity* as the intended
duration — estimated by least-squares regression over the whole visible envelope
rather than by a single threshold crossing. Same question, better estimator,
and valid under right-censoring because a partial decay still determines a
slope. This keeps the change inside Phase 1.

### Open risk: slots 8 and 9 may be collinear

If both become pure functions of one decay constant they carry the same
information, degrading the covariance model. Real taps are multi-modal — early
decay is typically faster than late — so a distinction should exist, but this is
an empirical question and shall be treated as one.

**Gate:** after the first Phase 1 calibration, compute the Pearson correlation
between slots 8 and 9 across all retained samples. If `|r| > 0.95`, stop and
report, with options: redefine slot 8 as decay *curvature* (residual of the
log-envelope fit) or as the early/late decay-rate ratio, both of which are still
event-aligned decay measurements and neither of which is a function of τ alone.

Diagonal loading (λ = 1e-3) already prevents a singular covariance, so the
failure mode is lost information, not a crash.

### Pipeline stages (ADR-017 §1)

```
1. Event detection      DECISION      peak amplitude only; "did something happen"
2. Event localisation   MEASUREMENT   walk back from event peak to onset
3. Event extraction     MEASUREMENT   absolute-position read anchored at onset
4. Feature computation  MEASUREMENT   ten features over the event window
5. Parameter derivation MODELLING     calibration only
6. Profile generation   MODELLING     calibration only
7. Runtime recognition  DECISION      unchanged logic, new space
```

Quality gates (duration, RMS, SNR) move **after** stage 3, where they are
measured against the event rather than the frame.

### Window-length derivation (ADR-017 §3)

Extraction begins with a provisional maximum bounded by the ring buffer
(16,384 samples = 341 ms at 48 kHz, ample). The decay of the first observed
calibration events is measured, the length that contains the measurable ring on
this hardware is fixed for the remainder of the session, recorded in the profile,
and reported. It is never an analytically chosen constant.

### Subsystems

| Subsystem | Why it changes | Behavioural / internal | Instrumentation valid | Reports comparable | New telemetry |
|---|---|---|---|---|---|
| **Audio** | Needs absolute-position extraction; `latestSamples(n)` only reads back from the write head | Behavioural (new read API; capacity already sufficient) | Yes | Yes | Underrun counter when an onset ages out |
| **DSP** | Envelope extraction; log-envelope regression | Additive; filters and FFT untouched | Yes | Yes | — |
| **Features** | All ten computed over the event window; slots 8–9 redefined | **Behavioural** | Golden tests regenerate | **No** | Censoring flag |
| **Detection** | Splits into detect → localise → extract; gates move after extraction | **Behavioural** | `nonDetectionObserver` stays; rejection-reason set changes | **No** | Onset offset, window used, censoring rate |
| **Calibration** | In-memory workspace; window and gate derivation; acoustic statistics in report | **Behavioural** | Rejection breakdown stays; causes change | **No** | Ring time, decay distribution, derived window and gates |
| **Classification** | New space, no logic change | **Internal** | Yes | Distances not comparable | — |
| **Configuration** | Schema gains derived gates and window; hard refusal on version mismatch | **Behavioural** | Yes | N/A | Refusal reason |
| **Runtime** | Consumes derived gates; pipeline reordered | **Behavioural** | Frame and candidate observers stay valid | **No** | Provenance of active gates |
| **Diagnostics** | New categories | Additive | Yes | Yes | — |
| **TapperApp** | Calibration gains a derivation phase; reports gain acoustic statistics | **Behavioural** | Phase 0 pacing fixes retained | **No** | — |
| **Inspection** | Reads new schema | Internal | N/A | N/A | — |
| **Developer build** | Separate product retaining snippets (ADR-017 §6) | New product | N/A | N/A | Snippet export |

### Success criteria

Distances and feature values are not comparable across the change, so Phase 1 is
judged on **space-independent outcome metrics** measured against the Phase 0
baseline:

| Metric | Current (untrustworthy pacing) | Phase 1 target |
|---|---|---|
| Calibration acceptance rate | 44.2% | Substantially higher |
| `durationAboveMaximum` share | 52.5% | Near-eliminated as a dominant cause |
| Runtime accuracy | 2% | Materially higher |
| False negatives | 90% | Materially lower |
| Unknown rate | 13.8% | Lower |
| **False positives** | **0%** | **Must not regress** |

The last row is a constraint, not a target. Any improvement bought with false
positives is not an improvement.

### Ordering

Documentation precedes code at each step, as throughout:

1. `ALGORITHM` §14 (feature definitions), §19/§23 (detection pipeline);
   `DATA_MODELS` §7 (profile schema)
2. Audio → DSP → Features → Detection → Calibration → Configuration → Runtime → App
3. Developer retention build

Every step buildable, `./Scripts/verify.sh` green, numerical claims verified by
hand before commit.

---

## Phase 2 — Feature space

Begins only after Phase 1 is validated on hardware.

Candidates, all of which require an event-anchored representation and are
therefore impossible before Phase 1:

- **Modal ratios** — second and third spectral peaks relative to the first.
  Plate modes vary with strike position, which is what zone discrimination
  needs, and ratios are invariant to how hard the user taps.
- **Spectral flux** — spectral evolution from attack through ring, computed over
  event-anchored sub-windows.
- **Onset slope** — rise *rate* rather than rise time; less sensitive to
  threshold choice than `attackTime`.

Dimension may increase. Normalization, covariance regularisation, the Cholesky
path, k-NN radii and the five-recogniser benchmark are all regenerated on the
Phase 1 foundation.

---

## Results invalidated by this work

Recorded so they are not cited later as evidence:

- **The five-recogniser benchmark** (ADR-016) and the **acceptance-radius
  instrumentation** are computed over a feature space that is substantially
  alignment noise. Neither can be interpreted until Phase 1 completes.
- **All validation runs before Phase 0** are confounded by the pacing defect.
- **Every calibration profile** predating Phase 1 is invalid and will be refused
  at load (ADR-017 §7).

No further hardware validation should be run until Phase 0 lands: it would
produce authoritative-looking numbers that mean nothing.
