# Decay Estimator — Design Note (for review)

**Status:** Proposed. Not yet specification. Review before `ALGORITHM` §14 is updated.

Every figure below was measured by running candidate estimators against
synthetic signals with known decay constants, through the project's real
band-pass filter. Nothing here is asserted from theory alone.

---

## 1. Mathematical definition

### 1.1 The physical quantity

A tap on a chassis is an impulse excitation of a damped resonant structure. Its
response is a sum of modes, each decaying exponentially:

```
x(t) = Σ Aᵢ · sin(2π fᵢ t + φᵢ) · exp(−t / τᵢ)
```

The physically meaningful quantity is the **decay time constant τ** — the time
for the envelope to fall by a factor of e. It is a property of the structure
and where it was struck, and is independent of how hard the tap was, of where
the analysis window begins, and of the microphone gain.

### 1.2 Envelope extraction

The envelope is estimated by **block RMS**:

```
env[k] = sqrt( (1/B) · Σ_{n=kH}^{kH+B-1} x[n]² )
```

with block `B = 96` samples (2 ms) and hop `H = 48` samples (1 ms) at 48 kHz.

Block RMS was chosen over the alternatives because:

- **Rectify-and-low-pass** introduces filter phase lag that biases the slope,
  and its own time constant contaminates the one being measured.
- **Hilbert / analytic envelope** is exact for a narrowband signal but requires
  an FFT per event and is not ripple-free for the multi-modal signal actually
  present.
- Block RMS averages the carrier out by construction, costs one pass, and has
  no state and no phase response to account for.

`B = 96` spans 1.4 periods at the observed dominant frequency (~700 Hz), which
suppresses carrier ripple. `H = 48` gives one envelope point per millisecond.

### 1.3 Regression model

The envelope is converted to decibels and a straight line is fitted by ordinary
least squares over a defined portion of the decay:

```
L(t) = 20 · log₁₀( env(t) )        [dB]
L(t) = L₀ − (8.6859 / τ) · t       [dB, t in seconds]
```

The coefficient is exact: `20 · log₁₀(e) = 8.685889638…`, the decibels lost per
time constant.

**Fit range.** From −5 dB below the envelope peak, down to −25 dB, or to 5 dB
above the measured noise floor, whichever is reached first. Starting at −5 dB
excludes the attack transient and any clipping, both of which are concentrated
at the peak and are not part of the decay.

**Units.** `t` in seconds; `env` dimensionless (same units as the normalized
signal); `L` in dB; slope in dB·s⁻¹; τ reported in milliseconds.

### 1.4 Deriving τ

```
τ = 8.685889638 / |slope|          [s, for slope in dB·s⁻¹]
```

### 1.5 Relation to the previous notion of duration

For an exponential decay the −20 dB duration and the time constant are related
by a constant factor:

```
T₂₀ = τ · ln(10) = 2.302585 · τ
```

So the estimator reports **the same physical quantity** the old
`signalDuration` intended to measure. What changes is the estimator: a
least-squares fit over the whole visible decay, instead of the interval between
two threshold crossings. This is why the change belongs to Phase 1 (measurement)
and not Phase 2 (features).

### 1.6 Why this measures the intended quantity

The slope of a log-envelope is invariant to the three things that corrupted the
previous measurement:

- **Amplitude.** Scaling `x` shifts `L` vertically and leaves the slope
  unchanged, so tap force does not affect τ.
- **Window origin.** Shifting the window shifts `t` and changes the intercept,
  not the slope. Measured alignment CV: **0.08%**.
- **Truncation.** A slope is determined by any two points on the line. Losing
  the tail costs precision, not correctness — unlike a threshold crossing,
  which is simply unavailable if the crossing falls outside the window.

---

## 2. Numerical behaviour

Measured with τ = 15 ms, 120 ms window, 700 Hz, amplitude 0.5.

### 2.1 Measurement noise

| SNR (dB) | τ error | r² | fit range (dB) | quality gate |
|---|---|---|---|---|
| 60 | +0.4% | 0.9986 | 20.0 | accept |
| 48 | +0.9% | 0.9981 | 20.0 | accept |
| 40 | +2.5% | 0.9966 | 20.0 | accept |
| 34 | +11.8% | 0.9871 | 17.3 | accept |
| 24 | +12.8% | 0.9438 | 7.7 | **reject** |
| 18 | +193% | 0.6286 | 1.8 | **reject** |

Degradation is graceful and monotone, and the fit's own r² tracks it. The gate
catches catastrophic failure reliably. It is **not** tight enough to catch the
+11.8% error at 34 dB, which passes at r² = 0.987 — so the recommended gate is
**r² ≥ 0.99 and fit range ≥ 15 dB**, and residual error of order 10% should be
expected near that boundary.

### 2.2 Very short decays

τ = 0.8 ms is **declined** (no estimate). The block/hop geometry sets a floor:
a fit needs several points, one per millisecond, spanning ≥ 10 dB, and 10 dB
takes 1.15 τ. Measured behaviour: τ = 1 ms declines, τ = 2 ms recovers to
+1.9%, τ ≥ 5 ms recovers to better than ±0.5%.

**Usable lower bound: τ ≈ 2 ms.** Well below anything observed on this hardware,
where taps ring beyond 30 ms.

### 2.3 Decays longer than the observation window

| window / T₂₀ | τ error |
|---|---|
| 0.43 | declined |
| 0.65 | +12.0% (censored) |
| 1.00 | +0.5% (censored) |
| 1.30 | +0.3% (censored) |
| 1.95 | +0.2% |
| 3.26 | +0.1% |

The estimator is accurate from window ≈ T₂₀ onward, and reports censoring below
about twice T₂₀. **This is the decisive property**, because the extraction
window will routinely be comparable to the decay.

### 2.4 Noise-dominated signals

Pure noise with no tap produces **no estimate** — the fit range collapses and
the estimator declines rather than returning a number. Fail-safe by
construction.

### 2.5 Incomplete observations

Covered by §2.3: truncation costs precision, not correctness, until the visible
range falls below roughly 10 dB.

### 2.6 Clipped signals

Amplitude 2.0 hard-clipped to ±1.0: **τ = 15.003 ms, r² = 0.9987** against a
true 15 ms. Essentially immune, because clipping is concentrated at the peak and
the fit begins 5 dB below it. This is a substantial advantage over any
peak-referenced or threshold-crossing measure.

### 2.7 Low-energy taps

Amplitude 0.01 (≈26 dB SNR): τ = 17.2 ms (+15%), r² = 0.961 — correctly
**flagged** by the quality gate.

### 2.8 Multi-modal decay

With a fast and a slow mode present, the fit returns approximately the **slower,
surviving** mode:

| τ_fast | τ_slow | reported τ | r² |
|---|---|---|---|
| 5 | 5 | 5.17 | 0.9844 |
| 5 | 15 | 14.70 | 0.9993 |
| 5 | 40 | 39.98 | 0.9995 |
| 3 | 60 | 60.27 | 0.9981 |

This is physically sensible — the fast mode has died before the fit range
begins — and it is stable. **Limitation to state plainly:** r² stays high, so
r² does not detect multi-modality when one mode dominates the fit range. The
estimator reports the decay of the dominant surviving mode, not an average, and
should be documented as such.

### 2.9 Stability

The computation is one pass of sums of squares, a logarithm per envelope point,
and a closed-form least-squares slope. There is no iteration, no matrix
inversion, and no convergence criterion. `log10` is guarded against zero by a
1e-12 floor. The only division is by the time variance of the fit points, which
is non-zero whenever ≥ 2 distinct points exist and is checked.

---

## 3. Censoring strategy

### 3.1 When a sample is censored

A sample is **censored** when the usable fit range is narrower than the nominal
range, i.e. when the decay reaches neither −25 dB below peak nor the window's
end before meeting the noise floor. Concretely, censored when:

```
fitRangeDB < 20 dB     (nominal −5 dB to −25 dB)
```

The record carries `fitRangeDB` and `censored`, not merely the τ value.

### 3.2 How censored observations participate in estimation

**They are used, at full weight, as measurements of τ.** No down-weighting.

### 3.3 Why they remain valid for regression

Because a slope is identified by any portion of the line. Truncation removes
points but does not bias the fit: the estimator is measuring the *rate* of
decay, which is the same rate whether observed over 10 dB or 30 dB. The
measurements confirm this — at window ≈ T₂₀ the error is +0.5%, and it stays
below 1% for every window ≥ T₂₀ despite every one of those observations being
censored.

What truncation costs is **variance**, not bias. Fewer points and a narrower
lever arm make the slope estimate noisier, which is exactly what `fitRangeDB`
and `r²` record.

### 3.4 Why they are invalid for threshold comparisons

A censored observation establishes a decay rate, not a completed event. Its
implied total duration `τ · ln(10)` is an **extrapolation beyond what was
observed**. Comparing that extrapolation against an upper bound asks a question
the data cannot answer: "did this tap last longer than X?" when the recording
stopped before X.

This is precisely the error in the current implementation, where a
right-censored `signalDuration` was compared against a 25 ms ceiling and taps
were rejected on the basis of a number that only reflected where the window
ended.

**Rule:** a censored measurement may enter statistics, models and reports. It
may never be the sole basis for rejecting an event against an upper bound.

---

## 4. Engineering trade-offs

| Estimator | Complexity | Robustness | Stability | Physical meaning | Implementation |
|---|---|---|---|---|---|
| **Threshold crossing** | O(n) | Fails under noise (saturates to window) | Trivial | Direct, but only if uncensored | Trivial |
| **Log-envelope OLS** *(chosen)* | O(n) | Graceful; self-reporting via r² | Closed form | τ directly | Low |
| **Schroeder + OLS** | O(n) | Excellent when window ≫ decay; collapses otherwise | Closed form | τ directly; ISO 3382 standard | Moderate (needs Lundeby truncation) |
| **Theil–Sen** | O(n²) | Best under outliers | Median, no division | τ directly | Moderate |
| **Segmented (two-slope)** | O(n·k) | Captures multi-modality | Breakpoint search can fail | Early vs late rate | High |

### Measured comparisons

**Threshold crossing** is accurate when the full decay is visible and noise is
low, but under noise it saturates to the window length (119.96 ms of a 120 ms
window at 24 dB SNR) and becomes meaningless. Its failure mode is silent.

**Schroeder backward integration** is the standard method for decay estimation
from an impulse response and was the initial candidate. Measured, it is the most
accurate estimator when the window comfortably contains the decay (−0.0% at
window/T₂₀ = 3.26) — and the worst when it does not:

| window / T₂₀ | Schroeder error | log-envelope error |
|---|---|---|
| 0.43 | −69.2% | declined |
| 1.00 | −33.0% | +0.5% |
| 1.30 | −18.7% | +0.3% |
| 1.95 | −3.4% | +0.2% |

It also degrades far worse under noise (+176% at 34 dB SNR, versus +11.8%),
because the backward integral accumulates the noise floor. Both problems are
addressable — Lundeby's iterative truncation is the standard remedy — but that
is a materially more complex algorithm with a convergence loop, and it is being
asked to compensate for exactly the regime we will operate in. **Rejected for
this problem, not in general.**

**Theil–Sen** is modestly better under noise (+7.4% vs +11.6% at 34 dB SNR;
+17.8% vs +22.2% at 24 dB) at O(n²) — about 600 pairwise slopes for a typical
35-point fit, which is not prohibitive. The improvement does not justify the
complexity while r² gating is available, but it is the natural fallback if
field data shows outlier-driven failures.

**Segmented regression** would capture the fast/slow structure of §2.8 and is
the most physically complete. It is deferred to **Phase 2**, where an early/late
rate ratio is a candidate *feature* — not a measurement fix.

### Why log-envelope OLS is preferred

It is the only candidate that is simultaneously accurate in the truncated
regime we will actually operate in, graceful under noise, immune to clipping,
closed-form, single-pass, and self-reporting through r² and fit range.

---

## 5. Verification

All figures produced by running the estimators over synthetic signals through
the real `ButterworthBandpass.v1`.

### 5.1 Recovery against ground truth (clean, 120 ms window)

| true τ | true T₂₀ | threshold crossing | log-envelope τ | error |
|---|---|---|---|---|
| 1 ms | 2.30 ms | 2.54 ms | declined | — |
| 2 ms | 4.61 ms | 4.71 ms | 2.038 ms | +1.9% |
| 5 ms | 11.51 ms | 11.77 ms | 5.007 ms | +0.1% |
| 10 ms | 23.03 ms | 23.21 ms | 10.026 ms | +0.3% |
| 20 ms | 46.05 ms | 46.06 ms | 20.011 ms | +0.1% |
| 40 ms | 92.10 ms | 91.77 ms | 40.157 ms | +0.4% |

**Expected numerical error: better than ±0.5% for 5 ms ≤ τ ≤ 40 ms at high SNR**,
rising to roughly ±2% at τ = 2 ms.

### 5.2 Independence from frame alignment

A physically identical tap (τ = 15 ms), band-passed, placed at onset offsets
from 0 to 40 ms within a 120 ms window:

| Estimator | CV across alignments |
|---|---|
| Threshold crossing | 0.6% |
| **Log-envelope** | **0.08%** |
| Schroeder | 0.51% |

Compare the present pipeline, where the same experiment gives 49% for
`signalDuration`.

**Important distinction:** the alignment problem is solved by *anchoring the
window to the event*, not by the choice of estimator — with a long enough
anchored window even threshold crossing is stable at 0.6%. The estimator choice
addresses censoring, noise and clipping. These are separate concerns and the
design note should not be read as claiming otherwise.

### 5.3 Theoretical limits on recovery

1. **Lower bound on τ.** A fit needs ≥ 3 envelope points (1 per ms) spanning
   ≥ 10 dB; 10 dB takes 1.15 τ. Hence τ ≳ 2 ms, confirmed empirically.
2. **Upper bound from window.** ≥ 10 dB of decay must be visible; 10 dB takes
   1.15 τ, so the post-onset window must exceed ≈ 1.2 τ for any estimate and
   ≈ 2.0 τ for an uncensored one.
3. **Noise floor.** Peak-to-noise must exceed the fit range plus the 5 dB
   margin. Below ≈ 30 dB SNR, errors of order 10% should be expected.
4. **Model limit.** A single slope cannot represent a multi-modal decay; §2.8
   shows it reports the dominant surviving mode, and r² does not flag this.

---

## 6. Implementation considerations

**Computational complexity.** O(N) for the envelope (one pass of squares),
O(M) for the fit where M ≈ window length in ms (~120). No iteration. Expected
well under 100 µs per event, off the audio thread.

**Memory.** One envelope array of M doubles (~1 KB). No allocation in the audio
callback; the estimator runs in the event-extraction stage.

**Numerical stability.** Closed-form slope; single division by time variance,
guarded; `log10` floored at 1e-12; no matrix operations.

**Failure cases and behaviour.**

| Case | Behaviour |
|---|---|
| Fewer than 3 fit points | Decline — no estimate |
| Zero time variance | Decline |
| Non-negative slope (rising envelope) | Decline |
| Pure noise | Decline (verified) |
| τ below resolution | Decline (verified at 0.8 ms) |
| Clipped input | Estimate valid (verified) |

Declining must be distinguishable from "estimated and rejected" — the same
distinction ADR-016 required for unevaluated recognisers.

**Telemetry to accompany every estimate.** `tau`, `fitRangeDB`, `r2`,
`pointCount`, `censored`, `peakToNoiseDB`, and the `declined` reason where
applicable. Without `fitRangeDB` and `r2` a τ value cannot be interpreted.

**Validation strategy.** Regenerate the alignment-sensitivity measurement that
found this defect (a physically constant tap swept across offsets) and require
CV below 1%; hardware calibration must report the distribution of `r2`,
`fitRangeDB` and censoring rate.

**Unit-test strategy.** Golden recovery against known τ at 2, 5, 10, 20, 40 ms
with exact expected values; alignment invariance; clipping immunity; graceful
decline on pure noise, on short decay, and on too-few points; the exact constant
8.685889638; and `T₂₀ = τ · ln(10)`.

---

## Resolved questions

### 1. Fit range — **fixed at −5 dB to −25 dB**

Measured, and the recommendation is the fixed range.

**No accuracy benefit from deriving it.** For a single exponential the estimate
is range-invariant, as theory requires — τ spans 15.002 to 15.102 ms (0.7%)
across six different ranges. For a realistic multi-modal decay the standard
ranges agree to 0.3% (39.892 to 40.005 ms); only a range starting at 0 dB,
which includes the attack peak, biases the result (38.605 ms).

**Deriving it would hide a systematic drift rather than remove it.** When the
achievable range shrinks with noise, the reported τ drifts upward:

| SNR (dB) | achievable range | reported τ |
|---|---|---|
| 64.9 | 20.0 dB | 39.980 ms |
| 44.9 | 20.0 dB | 40.160 ms |
| 32.8 | 17.6 dB | 42.276 ms |
| 24.9 | 10.6 dB | 45.501 ms |

That is a +14% drift at 25 dB SNR. With a **fixed nominal range**, this drift is
*detectable*: `fitRangeDB` falls below 20 and the sample is flagged censored.
With a **derived range**, the estimator would report "I used the best range
available" and the drift would be invisible — the same class of error as
comparing a censored duration against a ceiling.

**Distinction worth preserving.** The estimator already has an adaptive *floor*:
the lower bound is `max(peak − 25 dB, noiseFloor + 5 dB)`. That is not a derived
range — it is a fixed target with a safety floor, and any shortfall is recorded
in `fitRangeDB`. Fixed target, recorded shortfall.

**Consequences:** deterministic, reproducible between calibrations, and it does
not complicate detector-parameter derivation, because every sample's τ is
computed the same way and its reliability is carried alongside it.

### 2. Quality gate — **r² ≥ 0.99 and fitRangeDB ≥ 15 dB**

**These thresholds are empirical, not theoretically motivated.** They come from
sweeping both against a population of 238 estimates (τ ∈ {5,10,15,20,30,40} ms ×
SNR ∈ {60,48,40,34,30,24,18} dB × 6 seeds), of which 42% were bad, defining bad
as absolute error above 10%:

| r² min | range min | accepted | false accept | false reject | good kept |
|---|---|---|---|---|---|
| 0.95 | 15 dB | 144 | 8 (5.6%) | 2 (2.1%) | 98.6% |
| 0.98 | 15 dB | 142 | 6 (4.2%) | 2 (2.1%) | 98.6% |
| **0.99** | **15 dB** | **130** | **0 (0.0%)** | **8 (7.4%)** | **94.2%** |
| 0.99 | 0 dB | 132 | 2 (1.5%) | 8 (7.5%) | 94.2% |
| 0.995 | 15 dB | 104 | 0 (0.0%) | 34 (25.4%) | 75.4% |
| 0.999 | any | 0 | — | 138 (58.0%) | 0.0% |

**Why r² ≥ 0.99.** It is the knee. It is the loosest threshold reaching zero
false acceptance, while retaining 94.2% of good estimates. Tightening to 0.995
costs a further 19 percentage points of good samples and buys nothing — false
acceptance is already zero. Loosening to 0.98 admits 4.2% bad estimates.

**Why 15 dB.** At r² ≥ 0.99, requiring 15 dB takes false acceptance from 2
samples to 0 at no cost in good samples retained (94.2% either way). The range
criterion catches the failures r² alone misses.

**Sensitivity.** The gate is sharp between 0.98 and 0.995 — accepted counts fall
from 142 to 104 across that interval — so 0.99 sits on a slope, not a plateau.
A shift of ±0.005 moves the accepted fraction by roughly 10 percentage points.
This should be re-measured against real hardware data at CP-2 rather than
treated as settled.

**Limits of the gate.** The population is synthetic single-exponential signals.
The gate does **not** protect against the multi-modal case of §2.8, where r²
stays above 0.998 while the estimator reports only the dominant surviving mode.
It detects noise and truncation, not model misspecification.

### 3. Slot 8 — **unchanged during Phase 1**

Decided: Phase 1 improves measurement, Phase 2 improves representation.
Temporary feature correlation is preferable to introducing a new feature before
the measurement architecture is validated.

Telemetry continues to be collected. If the collinearity gate (|r| > 0.95
between slots 8 and 9) is exceeded, it is documented and the evidence presented
before any feature definition changes.
