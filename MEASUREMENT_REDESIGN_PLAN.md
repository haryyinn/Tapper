# Measurement Redesign — Implementation Plan

Implements ADR-017.

## Progress (2026-10-25)

| Step | State |
|---|---|
| Phase 0 — harness correctness | Done (`5d9ac35`) |
| Docs — `ALGORITHM` §14, §19.6, §23.4.1–23.5; `DATA_MODELS` §7.7 | Done |
| Audio — absolute-position reads | Done |
| DSP — `DecayEstimator` | Done |
| Features — measurement over the event window | Done |
| **CP-1** (offline alignment regression) | **Passed**, see below |
| Detection — detect → localise → extract → validate | Done |
| Configuration — refusal of pre-2.0 profiles | Done |
| Runtime / App — stream stepping, event telemetry in report | Done (wiring needed to reach CP-2) |
| **CP-2** (first hardware stop, 2026-10-26) | Done. Acceptance 75.5% (≥ 70% ✅). Fixed 25 ms limit rejected 16% (< 10% ❌); 92.5% censored; 0% high-confidence (❌) |
| Calibration — 70 ms window, derived duration limit (CP-3) | Done in code; profile version 2.1 |
| **CP-3** (second hardware stop) | **Next: fresh calibration on hardware** |

CP-1 result. A constant synthetic tap swept across 52 frame offsets gave these
coefficients of variation: `signalDuration` 0.09% (target < 1%),
`spectralBandwidth` 0.96%, `spectralCentroid` 0.31%, `zeroCrossingRate` 3.32%,
`rmsEnergy` 0.05% (targets < 5%). Recovery of τ was within ±2% for
2 ms ≤ τ ≤ 40 ms. The estimator declines on silence and on sustained tones.
Clipping the top 3 dB of the attack leaves τ within 3%. In a streamed
simulation (random offsets, uneven write chunks, τ from 3 to 25 ms) 500 of 500
taps were accepted and none counted twice.

Deviations recorded:

- Runtime was wired before CP-2, because a hardware calibration cannot run end
  to end without it.
- The event window is a constant (70 ms) set once from the CP-2 measurements,
  not derived per session as ADR-017 §3 asks. A per-session window would change
  the measurement domain between calibration and runtime and make profiles
  incomparable (`ALGORITHM` §23.4.1).

CP-2 → CP-3 rationale. CP-2 measured a median decay τ of 16.3 ms (p10 9.4,
p90 32.5), so a median tap fades by 20 dB in about 37 ms. That outlasts the
40 ms window and exceeds the fixed 25 ms limit. In a simulation of taps drawn
from that distribution, the 70 ms window cut censoring from 92.5% to 22% and
raised high-confidence fits from 0% to 92%. The derived limit (113 ms) accepted
200 of 200 taps, where the fixed 25 ms limit accepted 85 of 200. Split into phases so that **one variable changes at a time**.

| Phase | Question it answers | Feature dimension |
|---|---|---|
| **0** | Can the harness measure an outcome at all? | 10 (unchanged, defective) |
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

**Work:** adapt the tap window to observed reaction times; measure processing
latency from frame receipt to outcome; relabel. No detector constant, no
feature, no recogniser touched.

**Scope: harness correctness only. No baseline run.**

A quantitative "before" benchmark was considered and deliberately dropped. The
current measurement is alignment-dominated, and a rigorous baseline taken
through it would quantify the artefact to a precision it does not deserve —
spending hardware time to obtain a number that is not a property of the system.
The existing reports already establish, sufficiently, that the current
architecture is untrustworthy.

**The current implementation is therefore treated as the baseline
architecture**, and the reports of 2026-07-28 stand as historical context rather
than as a benchmark:

| Metric | Recorded 2026-07-28 |
|---|---|
| Calibration acceptance | 44.2% (80 of 181) |
| `durationAboveMaximum` | 52.5% of attempts |
| Runtime accuracy | 2% (2 of 100) |
| False negatives | 90% |
| False positives | 0% (0 of 60) |

These are context, not a denominator. Phase 1 is judged on whether it produces a
system that works, not on a delta against an artefact.

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
judged on **space-independent outcome metrics**, read as absolute properties of
the resulting system rather than as deltas against an artefact:

| Metric | Historical context | Phase 1 expectation |
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
- **All validation runs before Phase 0** are confounded by the pacing defect and
  stand as historical context only.
- **Every calibration profile** predating Phase 1 is invalid and will be refused
  at load (ADR-017 §7).

No further hardware validation should be run until Phase 0 lands: it would
produce authoritative-looking numbers that mean nothing. The next hardware
session should be the Phase 1 calibration.

---

# Phase 1 — Human Testing Checkpoints

Implementation pauses at defined points for hardware validation. The principle:
**stop as soon as a subsystem makes a user-observable claim testable**, rather
than after the whole phase.

## Summary

| Subsystem | Build | Unit | Hardware test? | Fresh calibration? | What to evaluate |
|---|---|---|---|---|---|
| Audio | ✅ | ✅ | ❌ | ❌ | Nothing user-visible; extraction correctness is offline |
| DSP | ✅ | ✅ | ❌ | ❌ | Envelope and slope recovery against known τ |
| Features | ✅ | ✅ | ⚠️ optional | ❌ | **Alignment CV re-measured offline** — the decisive regression |
| Detection | ✅ | ✅ | ✅ **STOP** | ✅ | **Acceptance rate, rejection breakdown, localisation** |
| Calibration | ✅ | ✅ | ✅ **STOP** | ✅ | Derived window and gates, decay statistics, censoring rate |
| Configuration | ✅ | ✅ | ⚠️ brief | ❌ | Old profile refuses to load with a clear message |
| Runtime | ✅ | ✅ | ❌ | ❌ | Defer — needs the Application layer to be exercisable |
| Application | ✅ | ✅ | ✅ **STOP** | ✅ | Full validation run; recognition evaluated **here for the first time** |

Three hardware stop points: **after Detection**, **after Calibration**, **after
Application**.

---

## CP-1 — After Features (offline only)

**A. Ready for calibration?** No. Continue implementing. The pipeline cannot run
end-to-end until Detection is anchored.

**B. Expected behaviour.** None observable. This is a pure measurement change.

**C. Metrics.** One, and it is the decisive regression for the whole phase:
re-run the alignment-sensitivity experiment — a physically constant tap swept
across window offsets — and confirm the coefficient of variation collapses.

| Feature | Before | Required |
|---|---|---|
| `signalDuration` → τ | 49% | **< 1%** |
| `spectralBandwidth` | 41% | < 5% |
| `spectralCentroid` | 27% | < 5% |
| `zeroCrossingRate` | 22% | < 5% |
| `rmsEnergy` | 19–23% | < 5% |

**Ignore for now.** Everything else. There is no recognition to evaluate.

**D. Stop point?** No — but if the CV targets are not met, **stop and report**.
Failing here means the anchoring is wrong and no later result would be
interpretable.

**E. Exit criteria.** All five CVs below target; τ recovery within ±2% of ground
truth for 2 ms ≤ τ ≤ 40 ms; estimator declines on pure noise; clipping immunity
demonstrated.

---

## CP-2 — After Detection (first hardware stop)

**A. Ready for calibration?** **Yes. Stop implementing.** Build the app, run a
fresh calibration, collect telemetry, review before continuing.

The extraction window is still a provisional constant at this point — window
derivation is Calibration's work. That is deliberate: it isolates *"does event
anchoring fix acceptance?"* from *"does derivation help?"*

**B. Expected behaviour.** Calibration should feel materially different:

- **Acceptance rate substantially above 44.2%.** Natural taps should mostly be
  accepted rather than mostly rejected.
- **`durationAboveMaximum` should largely disappear** as a rejection cause. It
  was 52.5%; a censored duration can no longer be compared against a ceiling.
- **Shorter session.** 181 attempts for 80 samples should fall towards ~100.
- **Rejections should feel justified** — genuinely mistimed or too-quiet taps,
  not taps that felt fine.
- If it still feels like being trained to tap, something is wrong. Say so.

**C. Metrics.**

- Calibration acceptance rate (was 44.2%)
- Rejection breakdown by cause (was: `durationAboveMaximum` 52.5%)
- Event-localisation quality: onset offset distribution, localisation failures
- Decay statistics: τ distribution, `r²` distribution, `fitRangeDB`
- Censoring rate — **first real measurement of whether taps outlast the window**
- Non-detection telemetry: unchanged instrumentation, should still function

**Ignore.** Recognition accuracy, unknown rate, recogniser benchmark. The profile
is new, the space has changed, and Runtime has not been updated. Any accuracy
number here is meaningless.

**D. Stop point?** **Yes — the most important one.** If acceptance has not
materially improved, the diagnosis is wrong and everything downstream is
premature.

**E. Exit criteria.**

- Acceptance rate **≥ 70%** (from 44.2%)
- `durationAboveMaximum` **< 10%** of attempts, or absent
- Event localisation succeeds on **≥ 95%** of detected candidates
- τ reported with `r² ≥ 0.99` on **≥ 80%** of accepted samples
- Censoring rate recorded (no threshold — this is the measurement that will
  *derive* the window in CP-3)
- Non-detection telemetry still populated

---

## CP-3 — After Calibration (second hardware stop)

**A. Ready for calibration?** **Yes. Stop implementing.** Fresh calibration
again, this time exercising window derivation and parameter derivation.

**B. Expected behaviour.** Similar to CP-2 but self-tuning: the session should
begin with a short derivation period, then proceed. Acceptance should be at
least as good as CP-2 and probably better, because the window now fits this
hardware. The calibration report should state the derived window and gates.

**C. Metrics.**

- Derived extraction window length, and the events it was derived from
- Derived detector parameters, with the distribution each came from
- Acceptance rate versus CP-2 — **must not regress**
- Censoring rate versus CP-2 — should fall, since the window is now fitted
- Decay statistics: τ per zone (do zones actually differ? first honest look)
- Collinearity gate: Pearson r between slots 8 and 9; escalate if |r| > 0.95
- Report completeness: acoustic statistics persisted although audio was not

**Ignore.** Recognition accuracy — Runtime is still on the old path.

**D. Stop point?** **Yes.** Derived parameters are the first output of the
"learn the user" architecture. If they are implausible, stop.

**E. Exit criteria.**

- Derived window produced and recorded in the profile
- Derived gates produced, each traceable to an observed distribution
- Acceptance rate ≥ CP-2
- Censoring rate ≤ CP-2
- In-memory workspace confirmed: **no audio anywhere in the saved profile**,
  verified by inspecting the JSON
- Calibration report contains window derivation, decay statistics, censoring
- Collinearity gate evaluated and reported

---

## CP-4 — After Application (final)

**A. Ready for calibration?** **Yes — full workflow.** Fresh calibration, then a
full validation run.

**B. Expected behaviour.** Recognition should work. This is the first point at
which accuracy is meaningful, because it is the first point at which the whole
chain — anchored measurement, derived parameters, models built from an
untruncated sample — is in place.

**C. Metrics.** Now everything:

- Recognition accuracy, per zone and overall
- Unknown rate, false negatives
- **False positives — constraint, must not regress from 0%**
- Timeout rate from the Phase 0 harness fix (was 32 of 100 silent)
- Processing latency, now correctly measured
- Recogniser benchmark — **re-runnable for the first time on trustworthy
  features**; the ADR-016 results are void until here
- Acceptance-radius instrumentation, likewise

**D. Stop point?** Yes — end of Phase 1. Phase 2 does not begin until these are
reviewed.

**E. Exit criteria.**

- False positives ≤ 0% baseline (**hard constraint**)
- Recognition accuracy materially above 2%
- Silent-trial rate < 10% (confirming the Phase 0 fix)
- Latency p95 within target, measured correctly
- No subsystem's instrumentation broken
- All Phase 1 documentation updated and consistent

---

## Discipline per subsystem

Every subsystem commit carries: documentation update, build verification,
numerical verification where arithmetic is involved, behavioural verification,
instrumentation verification, and regression analysis where prior measurements
exist. No batching of behavioural changes.
