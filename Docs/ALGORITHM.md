# 04_ALGORITHM.md

> **Tapper — Deterministic Recognition Algorithm Specification**
>
> **Version:** 2.0  
> **Status:** Engineering Specification  
> **Applies To:** Tapper v1.x  
> **Audience:** Software Engineers, DSP Engineers, AI Coding Agents (Claude), Technical Reviewers

---

# 1. Purpose

This document formally specifies the complete recognition algorithm used by **Tapper**.

Unlike a traditional product specification, this document does **not** describe features or user interaction. Instead, it defines the deterministic digital signal processing (DSP) pipeline responsible for converting raw acoustic data from the MacBook's built-in microphone into validated tap events that trigger user-defined actions.

This specification exists to eliminate ambiguity during implementation.

Every stage of the recognition pipeline—from microphone capture to command execution—is explicitly defined so that independent implementations produce equivalent runtime behaviour.

This document is considered the canonical specification for the Tapper recognition engine.

---

# 2. Scope

This specification defines:

- Audio acquisition
- Signal preprocessing
- Digital filtering
- Windowing
- Frequency-domain analysis
- Feature extraction
- Calibration
- Statistical modelling
- Runtime classification
- Noise rejection
- False-positive mitigation
- Confidence estimation
- Tap validation
- Cooldown management
- Recognition state transitions
- Diagnostics generation

The following are **outside the scope** of this document:

- User Interface
- SwiftUI implementation
- Settings persistence
- File formats
- Profile synchronization
- Application lifecycle
- Permission management
- Command execution APIs

Those topics are documented separately.

---

# 3. Design Philosophy

The Tapper recognition engine is built around one fundamental principle:

> **Recognition must always be deterministic.**

Given:

- identical calibration data
- identical configuration
- identical audio samples

the algorithm **must always** produce the same output.

The recognition engine shall never depend upon:

- Artificial Intelligence
- Machine Learning
- Neural Networks
- Cloud inference
- Adaptive black-box models
- External services

Every recognition decision must be explainable using measurable acoustic properties.

This philosophy provides several advantages:

- predictable behaviour
- reproducible results
- low computational cost
- offline operation
- easier debugging
- complete transparency

The algorithm intentionally favors engineering simplicity, repeatability and maintainability over probabilistic prediction.

---

# 4. Design Goals

The recognition engine shall satisfy the following objectives.

## 4.1 Determinism

Every execution of the algorithm shall produce identical output for identical input.

No hidden state or stochastic behaviour is permitted.

---

## 4.2 Low Latency

Recognition must feel instantaneous.

Target end-to-end latency:

**< 50 milliseconds**

from physical tap to command dispatch.

---

## 4.3 Low CPU Utilization

Tapper shall execute continuously without noticeable impact on system responsiveness.

Target CPU utilization:

**< 5% average**

during continuous listening.

---

## 4.4 Low Memory Usage

The recognition pipeline shall operate using streaming computation.

The application shall avoid storing unnecessary historical audio.

Target runtime memory:

**< 100 MB**

---

## 4.5 High Recognition Accuracy

Following successful calibration, the algorithm should achieve:

| Metric | Target |
|---------|---------|
| Recognition Accuracy | ≥95% |
| False Positive Rate | <1% |
| False Negative Rate | <5% |

---

## 4.6 Explainability

Every recognition decision shall be traceable.

The diagnostics engine must be capable of explaining:

- why a tap was accepted
- why a tap was rejected
- confidence score
- dominant features
- rejection reason

No hidden decisions are permitted.

---

# 5. Engineering Constraints

The recognition engine operates under several practical constraints imposed by macOS hardware.

The algorithm assumes:

- Built-in MacBook microphone
- Single audio input device
- Continuous microphone access
- Stable sampling frequency
- User calibration completed

The engine shall continue operating even under moderate environmental noise.

Examples include:

- conversation
- air conditioning
- ceiling fan
- office ambience
- café background noise

The algorithm is **not** expected to function correctly when:

- microphone permission is denied
- microphone hardware fails
- audio samples become corrupted
- calibration data is invalid
- hardware differs substantially from calibrated hardware

---

# 6. Recognition Architecture

The recognition engine is implemented as a streaming pipeline.

Each processing stage performs a single well-defined responsibility before forwarding the resulting data to the next stage.

```text
┌─────────────────────┐
│ Built-in Microphone │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Audio Acquisition   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Circular Buffer     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ DC Offset Removal   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Band-pass Filter    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Peak Normalization  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Window Generation   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Hann Window         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ FFT                 │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Feature Extraction  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Feature Vector      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Mahalanobis Engine  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Threshold Validation│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Cooldown Check      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Execute Action      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Diagnostics Logging │
└─────────────────────┘
```

Each stage is intentionally isolated.

No stage may modify responsibilities belonging to another stage.

This separation simplifies testing, debugging, maintenance and future algorithm evolution.

---

# 7. Audio Acquisition

## 7.1 Audio Source

The recognition engine uses the built-in MacBook microphone as its exclusive input source.

External microphones are outside the scope of Version 1.

Using a single hardware profile significantly improves calibration consistency.

---

## 7.2 Sampling Format

The audio subsystem shall provide:

| Property | Value |
|----------|------:|
| Channels | 1 (Mono) |
| Sample Rate | 48,000 Hz |
| Sample Format | 32-bit Float PCM |
| Endianness | Native |
| Stream Mode | Continuous |

Mono capture is sufficient because localization is performed statistically rather than through stereo spatial analysis.

---

## 7.3 Continuous Streaming

The microphone stream is never explicitly started or stopped during normal operation.

Instead, Tapper continuously receives PCM samples while recognition remains enabled.

This design eliminates startup latency associated with repeatedly initializing the audio pipeline.

---

## 7.4 Circular Buffer

Incoming samples are written into a rolling circular buffer.

The circular buffer provides:

- constant memory usage
- continuous streaming
- overlap generation
- deterministic latency
- efficient access

Old samples are overwritten automatically as new samples arrive.

No unbounded audio history is retained.

---

## 7.5 Timestamping

Every incoming buffer shall receive a high-resolution timestamp.

This timestamp propagates through the pipeline and enables:

- latency measurement
- diagnostics
- cooldown enforcement
- chronological logging
- performance analysis

The timestamp associated with a recognized tap corresponds to the beginning of the candidate window.

---

# 8. Signal Preprocessing

Raw microphone data contains components that are not useful for recognition.

Preprocessing standardizes the signal before any classification occurs.

The preprocessing pipeline shall always execute in the following order:

1. DC Offset Removal
2. Clipping Detection
3. Band-pass Filtering
4. Peak Normalization
5. Window Generation

Changing this order is not permitted without revising this specification.

---

# 9. Digital Filtering

## 9.1 Purpose

The objective of digital filtering is to maximize the signal-to-noise ratio (SNR) of a physical tap before feature extraction begins.

Raw microphone input contains numerous acoustic components unrelated to intentional tap events, including:

- Human speech
- HVAC and fan noise
- Keyboard typing
- Trackpad clicks
- Mechanical vibrations
- Low-frequency desk resonance
- High-frequency electrical noise

The filter stage suppresses these unwanted frequency components while preserving the transient impulse generated by a valid tap.

Filtering shall always occur before normalization, windowing, and feature extraction.

---

## 9.2 Filter Selection

Tapper shall use a **4th-order Butterworth Band-Pass IIR Filter**.

This choice balances:

- Computational efficiency
- Minimal latency
- Smooth passband response
- Stable real-time execution
- Low CPU utilization

Alternative filter families were evaluated but rejected.

| Filter Type | Decision | Reason |
|-------------|----------|--------|
| Butterworth | ✅ Selected | Maximally flat response, computationally efficient |
| Chebyshev Type I | ❌ Rejected | Ripple within passband |
| Chebyshev Type II | ❌ Rejected | Ripple within stopband |
| Elliptic | ❌ Rejected | Excessive phase distortion |
| FIR | ❌ Rejected | Higher computational cost and increased latency |
| Bessel | ❌ Rejected | Poor attenuation outside passband |

Butterworth filtering provides the most predictable behaviour while preserving transient waveform characteristics.

---

## 9.3 Filter Parameters

| Parameter | Value |
|-----------|------:|
| Type | Butterworth |
| Order | 4 |
| Lower Cutoff | 300 Hz |
| Upper Cutoff | 6000 Hz |
| Sample Rate | 48,000 Hz |

---

## 9.4 Lower Cutoff Frequency

Frequencies below **300 Hz** primarily contain:

- Desk resonance
- Laptop chassis movement
- Air conditioning rumble
- HVAC systems
- Mechanical vibrations
- Footsteps
- Building vibration

These components contain little useful information for identifying tap locations.

Removing them significantly improves robustness.

---

## 9.5 Upper Cutoff Frequency

Frequencies above **6000 Hz** typically consist of:

- Electrical interference
- Sensor noise
- High-frequency hiss
- Minor aliasing artifacts

Tap energy contributes very little beyond this range.

Filtering these frequencies reduces unnecessary variance during feature extraction.

---

## 9.6 Frequency Response

The selected passband preserves the dominant acoustic energy produced by tapping the MacBook chassis while attenuating unrelated environmental noise.

Expected behaviour:

- Smooth gain across passband
- No ripple
- Monotonic attenuation
- Stable phase response suitable for transient detection

---

## 9.7 Runtime Requirements

The filtering stage shall:

- Process every incoming analysis window
- Operate continuously
- Never allocate heap memory during runtime
- Produce deterministic output
- Maintain constant execution time

---

# 10. Peak Normalization

## 10.1 Purpose

Different users naturally apply different tapping forces.

Without normalization, classification accuracy would become dependent upon tap strength rather than acoustic signature.

Normalization removes this dependency.

The recognition engine shall classify **how** a tap sounds rather than **how loud** it is.

---

## 10.2 Method

Each candidate window shall be normalized independently.

Peak normalization scales the waveform such that:

- Maximum absolute amplitude equals 1.0
- Remaining samples are scaled proportionally

The resulting waveform lies within:

```text
[-1.0, +1.0]
```

This normalization preserves waveform shape while removing amplitude bias.

---

## 10.3 Advantages

Peak normalization provides:

- Consistent feature extraction
- Comparable calibration samples
- Improved classification stability
- Reduced user dependence

---

## 10.4 Limitations

Normalization cannot recover clipped signals.

If clipping is detected before normalization, the candidate shall be rejected.

---

# 11. Window Generation

## 11.1 Purpose

The recognition engine does not process an infinite audio stream directly.

Instead, the signal is divided into overlapping analysis windows.

Each window represents a short time interval suitable for frequency-domain analysis.

---

## 11.2 Window Duration

Default window length:

| Property | Value |
|----------|------:|
| Duration | 40 ms |
| Sample Rate | 48 kHz |
| Samples per Window | 1920 |

This duration captures the complete acoustic signature of a typical tap without introducing unnecessary latency.

---

## 11.3 Window Overlap

Adjacent windows overlap by **50%**.

This results in:

```text
Window 1

████████████████

        Window 2

        ████████████████

                Window 3

                ████████████████
```

---

## 11.4 Benefits of Overlap

Window overlap provides:

- Continuous coverage
- Reduced boundary effects
- Improved transient capture
- Higher temporal resolution

Without overlap, taps occurring near window boundaries could be partially missed.

---

## 11.5 Window Metadata

Every analysis window shall include:

- Start timestamp
- End timestamp
- Window index
- Raw PCM samples
- Filtered samples
- Energy estimate

This metadata supports diagnostics and latency analysis.

---

# 12. Window Function

## 12.1 Purpose

Directly applying an FFT to raw finite-length signals introduces spectral leakage.

Window functions reduce discontinuities at window boundaries.

---

## 12.2 Selected Window

Tapper shall use the **Hann Window**.

Advantages:

- Excellent leakage suppression
- Low computational cost
- Smooth edge tapering
- Widely used in transient signal analysis

---

## 12.3 Alternatives Considered

| Window | Decision | Reason |
|---------|----------|--------|
| Hann | ✅ Selected | Best balance between leakage and resolution |
| Hamming | ❌ Rejected | Slightly poorer leakage performance |
| Blackman | ❌ Rejected | Wider main lobe reduces frequency resolution |
| Rectangular | ❌ Rejected | Excessive spectral leakage |

---

## 12.4 Application

The Hann window shall be applied after normalization and before FFT computation.

Each sample is multiplied by the corresponding Hann coefficient.

This operation smooths the edges of the analysis window while preserving the internal transient structure.

---

# 13. Fast Fourier Transform (FFT)

## 13.1 Purpose

Tapper performs frequency-domain analysis because tap locations exhibit distinctive spectral characteristics that are difficult to distinguish in the time domain alone.

The FFT converts each window into its frequency representation.

---

## 13.2 FFT Size

| Parameter | Value |
|-----------|------:|
| FFT Length | 2048 |
| Sample Rate | 48,000 Hz |
| Frequency Resolution | ≈23.44 Hz per bin |

The FFT size is intentionally larger than the analysis window, allowing efficient radix-2 computation while providing sufficient frequency resolution.

---

## 13.3 Output

The FFT produces:

- Magnitude Spectrum
- Phase Spectrum

For Version 1, only the magnitude spectrum is required.

Phase information is intentionally ignored because it contributes little to deterministic tap localization.

---

## 13.4 Runtime Requirements

FFT computation shall:

- Execute once per analysis window
- Complete within the latency budget
- Avoid dynamic memory allocation
- Produce deterministic results
- Use identical numerical precision across platforms

---

## 13.5 Numerical Stability

Implementations should minimize floating-point accumulation error and ensure repeatable results across identical hardware.

Minor floating-point differences that do not alter classification outcomes are acceptable.

---

# 14. Feature Extraction

## 14.1 Purpose

Feature extraction transforms a validated acoustic event into a deterministic numerical representation suitable for statistical classification.

Rather than comparing raw waveforms directly, Tapper represents every tap as a fixed-length feature vector describing its temporal and spectral characteristics. This approach significantly improves robustness while maintaining deterministic behaviour.

Every candidate tap passing the preprocessing pipeline shall undergo feature extraction.

The resulting feature vector becomes the sole input to the classification engine.

No raw audio samples are compared during runtime classification.

### 14.1.1 Measurement Domain (ADR-017)

Every feature in this section shall be computed over the **event window** of
§23.4.1 — a window anchored at the localised onset of the event — and never over
the poll-aligned analysis frame that triggered detection.

This is not a matter of preference. A quantity measured against the analysis
frame inherits the arbitrary phase between the frame and the event: measurement
showed a physically identical tap varying by 49% in duration, 41% in spectral
bandwidth, 27% in spectral centroid, 22% in zero-crossing rate and 19-23% in
RMS energy, purely as a function of where it fell in the frame.

The distinction that governs this section:

- Features defined **relative to the event** — its onset or its peak — are
  alignment-invariant. Peak amplitude, attack time and decay time measured 0%
  variation under the same test.
- Features defined as **whole-window aggregates** are alignment-invariant only
  if the window itself is anchored to the event.

Anchoring the window is therefore a precondition for every feature below, not
an optimisation.

---

## 14.2 Design Objectives

The extracted feature set shall satisfy the following requirements:

- Computationally efficient
- Deterministic
- Robust against moderate noise
- Independent of tap force where possible
- Stable across repeated taps
- Capable of discriminating interaction zones
- Resistant to minor timing variations

Each feature shall contribute measurable information regarding the physical characteristics of a tap.

No redundant features should be included unless they improve classification stability.

---

## 14.3 Feature Categories

The recognition engine extracts two categories of features.

### Time-Domain Features

These describe the waveform directly.

Examples include:

- Peak Amplitude
- RMS Energy
- Attack Time
- Decay Time
- Signal Duration
- Zero Crossing Rate

---

### Frequency-Domain Features

These describe the spectral characteristics obtained from the FFT.

Examples include:

- Spectral Centroid
- Spectral Bandwidth
- Spectral Roll-off
- Dominant Frequency

The combination of temporal and spectral information provides significantly greater discrimination than either domain alone.

---

# 14.4 Peak Amplitude

## Definition

Peak Amplitude is the maximum absolute sample value observed within the normalized signal.

## Formula

PeakAmplitude = max(|x[n]|)

where

- x[n] is the normalized waveform

---

## Units

Normalized amplitude

Range:

0.0 – 1.0

---

## Purpose

Peak Amplitude measures the strongest instantaneous pressure impulse produced by the tap.

Although peak normalization reduces dependence on tapping force, this feature remains valuable for rejecting extremely weak events that resemble ambient noise.

---

## Contribution

Classification Importance:

Low

Validation Importance:

High

Peak Amplitude is primarily used during candidate validation rather than zone discrimination.

---

## Edge Cases

Very low peak amplitude may indicate:

- missed tap
- distant vibration
- microphone obstruction
- environmental noise

Such candidates are generally rejected before classification.

---

# 14.5 RMS Energy

## Definition

Root Mean Square (RMS) Energy measures the average signal power over the analysis window.

Unlike Peak Amplitude, RMS Energy reflects sustained acoustic energy.

---

## Formula

RMS = √((1/N) Σ x²[n])

where

N = number of samples

---

## Units

Normalized Energy

---

## Purpose

RMS Energy distinguishes legitimate taps from low-energy disturbances.

Strong taps produce a short burst of concentrated energy.

Speech and fan noise typically produce lower and more distributed RMS values.

---

## Contribution

Classification Importance:

Medium

Validation Importance:

Very High

---

## Expected Behaviour

Typical observations:

Weak noise

↓

Low RMS

Keyboard typing

↓

Medium RMS

Intentional tap

↓

High RMS

---

# 14.6 Spectral Centroid

## Definition

The Spectral Centroid represents the "center of mass" of the frequency spectrum.

It approximates the perceived brightness of a sound.

---

## Formula

SpectralCentroid

=

Σ(fᵢAᵢ)

/

Σ(Aᵢ)

where

- fᵢ = frequency bin
- Aᵢ = magnitude

---

## Units

Hertz (Hz)

---

## Purpose

Different tap locations excite different chassis resonances.

These resonances shift the energy distribution across the spectrum.

The Spectral Centroid captures this shift.

---

## Contribution

Classification Importance:

Very High

This is one of the strongest features for zone discrimination.

---

## Edge Cases

Broadband noise may produce unstable centroid estimates.

Candidates with extremely low signal energy should not compute centroid values.

---

# 14.7 Spectral Bandwidth

## Definition

Spectral Bandwidth measures the spread of spectral energy around the centroid.

It indicates whether energy is concentrated within a narrow frequency range or distributed broadly.

---

## Units

Hertz

---

## Purpose

Tap locations often differ in resonance complexity.

Some zones produce concentrated resonances.

Others generate wider spectral distributions.

Bandwidth captures this distinction.

---

## Contribution

Classification Importance:

High

---

# 14.8 Spectral Roll-off

## Definition

Spectral Roll-off is the frequency below which 85% of the spectral energy is contained.

---

## Purpose

Roll-off provides another description of spectral shape.

It complements Spectral Centroid by describing energy accumulation rather than average position.

---

## Contribution

Classification Importance:

Medium

---

# 14.9 Dominant Frequency

## Definition

Dominant Frequency is the FFT bin containing the maximum magnitude.

---

## Units

Hertz

---

## Purpose

Each interaction zone tends to excite one or more dominant chassis resonances.

Although not perfectly stable on its own, Dominant Frequency contributes useful discriminative information when combined with the remaining features.

---

## Contribution

Classification Importance:

High

---

# 14.10 Zero Crossing Rate

## Definition

Zero Crossing Rate (ZCR) is the number of sign changes occurring within the waveform.

---

## Formula

ZCR = Number of Sign Changes / Window Length

---

## Units

Crossings per sample

---

## Purpose

ZCR differentiates impulsive taps from slowly varying mechanical disturbances.

Higher-frequency content generally increases ZCR.

---

## Contribution

Classification Importance:

Medium

Validation Importance:

Medium

---

# 14.11 Attack Time

## Definition

Attack Time measures the interval between signal onset and maximum amplitude.

---

## Units

Milliseconds

---

## Purpose

Intentional taps exhibit extremely rapid attack characteristics.

Mechanical movement and desk vibrations typically rise much more slowly.

---

## Contribution

Classification Importance:

High

---

# 14.12 Decay Time

## Definition

Decay Time measures the interval required for the waveform to return to the ambient noise floor after reaching peak amplitude.

### 14.12.1 Known Discrepancy (ADR-017)

The Version 1 implementation does not measure this quantity. It stops at the
first sample after the peak falling below the offset threshold, which on an
oscillating waveform is the approach to the next zero crossing rather than the
end of the decay. Measurement bears this out: the observed mean of 0.294 ms
corresponds closely to a quarter period at the observed mean dominant frequency
of 695.8 Hz, which is 0.359 ms. The feature therefore restates
`Dominant Frequency` rather than describing the decay.

This discrepancy is **recorded and deliberately left in place for Phase 1**,
which corrects the measurement architecture while holding the feature set fixed.
Correcting it requires an envelope-based definition, which changes what the
feature measures and therefore belongs to the representation work of Phase 2.

The feature shall continue to be computed over the event window of §23.4.1 like
every other, so its value changes with the anchoring even though its definition
does not.

Two consequences follow and shall be observed:

- `Decay Time` and `Signal Duration` (§14.13) may prove strongly correlated once
  both are computed over an anchored window. Correlation between the two shall
  be reported from calibration telemetry, and evidence presented before any
  definition is changed.
- No detector gate shall be derived from `Decay Time` while this discrepancy
  stands.

---

## Units

Milliseconds

---

## Purpose

Different chassis locations exhibit different damping behaviour.

This feature captures those resonance decay characteristics.

---

## Contribution

Classification Importance:

High

---

# 14.13 Signal Duration

## Definition

Signal Duration measures how long the event's acoustic energy persists,
expressed as the interval over which the decay envelope falls by 20 dB.

It shall be derived from the **decay rate** of the event envelope, not from
threshold crossings within the observation window.

---

## Units

Milliseconds

---

## Measurement (ADR-017)

### 14.13.1 Envelope

The envelope of the event window shall be estimated by block RMS:

```
env[k] = sqrt( (1/B) * SUM x[n]^2 )     n = kH .. kH+B-1
```

with block `B` spanning at least one period of the lowest passband frequency
and hop `H` giving at least one envelope point per millisecond. For the Version
1 settings, `B = 96` samples (2 ms) and `H = 48` samples (1 ms) at 48 kHz.

### 14.13.2 Decay Rate

The envelope shall be expressed in decibels and a straight line fitted by
ordinary least squares:

```
L(t) = 20 * log10( env(t) )
L(t) = L0 - (8.685889638 / tau) * t
```

The coefficient `20 * log10(e) = 8.685889638` is the decibels lost per time
constant and is exact.

The fit range shall be **fixed**: from 5 dB below the envelope peak down to 25
dB below it, or to 5 dB above the measured noise floor, whichever is reached
first. Beginning 5 dB below the peak excludes the attack transient and any
clipping, neither of which is part of the decay.

The fit range shall not be derived per event. A derived range produces a
systematic drift as the achievable range shrinks with noise — measured at +14%
at 25 dB SNR — while reporting no indication that it has done so. A fixed
target with a recorded shortfall makes the same drift detectable.

### 14.13.3 Reported Quantity

```
tau = 8.685889638 / |slope|      slope in dB per second
Signal Duration = tau * ln(10)
```

For an exponential decay the -20 dB duration and the time constant differ by
the constant factor `ln(10) = 2.302585`, so this reports the same physical
quantity the previous threshold-crossing definition intended to measure. Only
the estimator changes.

### 14.13.4 Reliability

Every estimate shall carry the fitted range in decibels, the coefficient of
determination of the fit, the number of fitted points, and its censoring status
(§14.13.5).

An estimate shall be regarded as high-confidence when `r^2 >= 0.99` and the
fitted range is at least 15 dB. These thresholds are **empirical**, chosen as
the loosest pair achieving zero false acceptance over a swept population while
retaining 94% of good estimates. They are subject to revision against hardware
data.

The reliability criteria detect noise and truncation. They do **not** detect
model misspecification: where an event contains several modes, the fit reports
the decay of the dominant surviving mode over the fitted range, and `r^2`
remains high. The reported quantity is the dominant mode's decay, not an average.

### 14.13.5 Censoring

An estimate is **censored** when the fitted range is narrower than the nominal
20 dB, that is when the decay meets the noise floor or the end of the event
window first.

Censored estimates shall participate fully, and at full weight, in statistics
and modelling. A slope is identified by any portion of the line, so truncation
costs variance and not bias; measurement confirms the error remains below 1%
for every window at least as long as the reported duration.

A censored estimate shall **never** be the sole basis for rejecting an event
against an upper bound. Its implied total duration extrapolates beyond what was
observed, and comparing that extrapolation against a ceiling asks whether the
event outlasted a limit the recording stopped before reaching. This was the
defect that ADR-017 corrects.

### 14.13.6 Declining to Estimate

The estimator shall produce no value, rather than an unreliable one, when fewer
than three envelope points fall inside the fit range, when the fitted points
have zero variance in time, or when the fitted slope is not negative.

Declining shall be distinguishable in every report from estimating and then
rejecting.

The measurable range is bounded below by the envelope resolution: a fit needs
several points spanning at least 10 dB, and 10 dB of decay takes 1.15 time
constants. For the Version 1 settings this places the lower bound at
approximately `tau = 2 ms`.

---

## Purpose

Tap duration provides information regarding the interaction between the user's
finger and the laptop chassis, and reflects the damping of the struck structure.

---

## Contribution

Classification Importance:

Medium

Validation Importance:

High

---

# 14.14 Feature Extraction Output

Upon completion of feature extraction, every validated candidate shall be represented as a deterministic feature vector containing the following values:

1. Peak Amplitude
2. RMS Energy
3. Spectral Centroid
4. Spectral Bandwidth
5. Spectral Roll-off
6. Dominant Frequency
7. Zero Crossing Rate
8. Attack Time
9. Decay Time
10. Signal Duration

No additional runtime information shall influence classification beyond this feature vector and the calibrated statistical model.

The feature vector produced by this stage forms the canonical representation of a tap and is passed directly to the classification engine.

# 15. Feature Vector

## 15.1 Purpose

Individual acoustic features provide only partial information regarding the physical location of a tap.

Reliable recognition is achieved by evaluating all extracted features collectively as a multidimensional statistical observation.

The Feature Vector is the canonical numerical representation of a tap and serves as the exclusive input to the classification engine.

Every validated tap shall produce exactly one feature vector.

The Feature Vector is immutable once constructed.

---

## 15.2 Design Objectives

The Feature Vector shall satisfy the following objectives:

- Fixed dimensionality
- Deterministic construction
- Device independent
- Efficient storage
- Fast comparison
- Numerical stability
- Suitable for statistical distance calculations

The vector shall contain only measurable acoustic quantities.

No heuristic values or inferred labels may be embedded within the vector.

---

## 15.3 Vector Structure

Each tap shall be represented by a ten-dimensional feature vector.

```
FeatureVector
{
    PeakAmplitude
    RMSEnergy
    SpectralCentroid
    SpectralBandwidth
    SpectralRollOff
    DominantFrequency
    ZeroCrossingRate
    AttackTime
    DecayTime
    SignalDuration
}
```

The ordering of features is fixed.

Implementations shall never reorder vector elements.

Changing feature order invalidates all existing calibration profiles.

---

## 15.4 Canonical Ordering

The Feature Vector shall always use the following order.

| Index | Feature |
|--------|---------|
| 0 | Peak Amplitude |
| 1 | RMS Energy |
| 2 | Spectral Centroid |
| 3 | Spectral Bandwidth |
| 4 | Spectral Roll-off |
| 5 | Dominant Frequency |
| 6 | Zero Crossing Rate |
| 7 | Attack Time |
| 8 | Decay Time |
| 9 | Signal Duration |

This ordering is considered part of the algorithm specification.

Future versions must maintain backward compatibility or explicitly version the feature format.

---

## 15.5 Data Representation

Each feature shall be represented as a 64-bit floating-point value.

Recommended implementation:

```
Double
```

Reasons:

- Improved numerical precision
- Stable covariance calculations
- Reduced rounding error
- Better reproducibility

Although most values could fit within 32-bit precision, the statistical calculations performed during calibration benefit from higher numerical accuracy.

---

## 15.6 Units

Each element shall retain its physical unit until normalization.

| Feature | Unit |
|---------|------|
| Peak Amplitude | Normalized |
| RMS Energy | Normalized |
| Spectral Centroid | Hz |
| Spectral Bandwidth | Hz |
| Spectral Roll-off | Hz |
| Dominant Frequency | Hz |
| Zero Crossing Rate | Crossings / Sample |
| Attack Time | ms |
| Decay Time | ms |
| Signal Duration | ms |

Maintaining physical units simplifies diagnostics and debugging.

---

## 15.7 Feature Normalization

The extracted features naturally exist on different numerical scales.

For example:

Peak Amplitude

```
0.87
```

Dominant Frequency

```
2850 Hz
```

Attack Time

```
4.2 ms
```

Without normalization, high-magnitude features would dominate the statistical distance calculation.

Therefore, all features shall be normalized before classification.

Normalization parameters are derived during calibration and stored within the calibration profile.

---

## 15.8 Normalization Strategy

For Version 1, Tapper shall perform feature normalization using the calibration statistics.

Each feature shall be transformed relative to the observed calibration distribution.

Normalization shall preserve:

- Relative ordering
- Statistical variance
- Distance relationships

No adaptive runtime normalization is permitted.

---

## 15.9 Feature Independence

The Feature Vector intentionally contains partially correlated features.

Examples include:

- Spectral Centroid
- Spectral Bandwidth
- Spectral Roll-off

Although these describe similar spectral properties, together they provide stronger discrimination than any single feature alone.

Correlation between features is explicitly handled by the covariance matrix during classification.

No attempt shall be made to artificially decorrelate features.

---

## 15.10 Feature Stability

Every selected feature should exhibit low intra-zone variance.

Repeated taps on the same interaction zone should produce similar feature values.

Conversely, taps on different interaction zones should exhibit measurable statistical separation.

This stability is fundamental to successful Mahalanobis classification.

---

## 15.11 Feature Validation

Before a Feature Vector is accepted, every element shall be validated.

Validation includes:

- Finite numerical value
- Not NaN
- Not Infinite
- Within physically reasonable limits

Invalid vectors shall be discarded immediately.

No attempt shall be made to repair corrupted feature vectors.

---

## 15.12 Feature Vector Object

Conceptually, each Feature Vector contains both acoustic measurements and runtime metadata.

```
FeatureVector
{
    UUID

    Timestamp

    Zone (Calibration Only)

    PeakAmplitude

    RMSEnergy

    SpectralCentroid

    SpectralBandwidth

    SpectralRollOff

    DominantFrequency

    ZeroCrossingRate

    AttackTime

    DecayTime

    SignalDuration
}
```

During runtime recognition, the Zone field is unknown.

During calibration, the Zone field is assigned by the calibration workflow.

---

## 15.13 Storage

Feature Vectors collected during calibration shall be stored only for the duration of the calibration session.

After statistical models have been computed, raw Feature Vectors may be discarded.

The persisted calibration profile shall contain only the derived statistical model.

This minimizes storage requirements while preserving all information necessary for recognition.

---

## 15.14 Runtime Lifecycle

For every detected tap:

```
Audio

↓

Feature Extraction

↓

Feature Vector

↓

Validation

↓

Normalization

↓

Classification

↓

Discard
```

Feature Vectors are transient runtime objects.

They shall not accumulate indefinitely.

The recognition engine is designed as a streaming system with constant memory usage.

---

## 15.15 Design Rationale

Representing taps as fixed-dimensional vectors provides several advantages:

- Constant-time comparison
- Efficient memory usage
- Straightforward statistical modeling
- Hardware-independent implementation
- Deterministic classification
- Extensible architecture

Additional features may be introduced in future versions provided that feature versioning is handled explicitly.

The Feature Vector defined in this section is the canonical interface between the Digital Signal Processing pipeline and the Statistical Classification Engine.

Subsequent sections define how these vectors are used to construct calibration profiles and perform runtime recognition.

# 16. Calibration Algorithm

## 16.1 Purpose

The purpose of calibration is to construct a statistical model describing the acoustic characteristics of each interaction zone on the user's MacBook.

Unlike adaptive or machine learning systems, Tapper does not continuously learn during runtime.

Calibration is the **only** phase during which statistical parameters are generated.

Once calibration has completed successfully, the recognition engine becomes read-only.

No runtime learning or parameter drift is permitted.

---

## 16.2 Design Philosophy

Calibration must produce a model that satisfies the following objectives:

- Deterministic
- Repeatable
- Device-specific
- User-independent
- Statistically representative
- Resistant to occasional poor taps

Calibration is intended to characterize the physical resonance properties of the laptop chassis rather than the user's tapping style.

---

## 16.3 Interaction Zones

Version 1 defines four interaction zones.

```
┌────────────────────────────┐
│ Top Left     Top Right     │
│                            │
│                            │
│ Bottom Left  Bottom Right  │
└────────────────────────────┘
```

Each zone is calibrated independently.

Future versions may introduce additional zones without altering the core algorithm.

---

## 16.4 Calibration Workflow

The calibration process follows a guided sequence.

```
Start Calibration

↓

Verify Microphone

↓

Verify Environment

↓

Select Zone

↓

Collect Tap Samples

↓

Validate Samples

↓

Reject Outliers

↓

Compute Statistics

↓

Compute Threshold

↓

Store Zone Profile

↓

Next Zone

↓

Calibration Complete
```

Each stage must complete successfully before proceeding.

---

## 16.5 Environment Verification

Before recording begins, Tapper shall verify that environmental conditions are suitable.

Checks include:

- Microphone available
- Permission granted
- Ambient noise below acceptable threshold
- Audio stream active
- DSP pipeline operational

Calibration shall not begin until all checks succeed.

---

## 16.6 Ambient Noise Measurement

Before recording taps, Tapper measures the ambient noise floor.

A short recording period (approximately two seconds) is used.

The measured baseline becomes the reference noise level for the calibration session.

This value is **not** persisted after calibration.

It exists solely to validate tap recordings.

---

## 16.7 Guided Tap Collection

For each interaction zone, the user is instructed to perform:

**20 intentional taps**

The application should provide clear visual feedback after every accepted tap.

Rejected taps shall not contribute toward the required sample count.

---

## 16.8 Sample Acceptance

Every recorded tap passes through the complete DSP pipeline.

A sample is accepted only if:

- Peak energy exceeds minimum threshold
- No clipping is detected
- Signal duration falls within expected range
- Candidate passes validation
- Cooldown requirements are satisfied

Rejected samples are discarded immediately.

---

## 16.9 Calibration Sample Count

Default sample count:

| Parameter | Value |
|-----------|------:|
| Samples per Zone | 20 |
| Zones | 4 |
| Total Samples | 80 |

Twenty samples provide sufficient statistical information while keeping calibration time reasonable.

Future versions may permit user-configurable sample counts.

---

## 16.10 Sample Validation

Each accepted tap is evaluated for quality.

Validation includes:

- Signal-to-noise ratio
- Complete waveform capture
- Stable feature extraction
- Valid feature vector
- Numerical consistency

Only validated Feature Vectors become calibration samples.

---

## 16.11 Outlier Detection

Human users occasionally produce accidental taps.

Examples include:

- Extremely weak taps
- Double taps
- Finger slips
- Desk impacts
- Partial contact

Such samples distort the statistical model.

Outlier detection removes these observations before model generation.

---

## 16.12 Outlier Rejection Strategy

Tapper shall perform deterministic outlier rejection.

Possible methods include:

- Mahalanobis distance
- Robust Z-score
- Median Absolute Deviation (MAD)

For Version 1, Mahalanobis-based rejection is recommended for consistency with the runtime classifier.

Samples exceeding the rejection threshold shall be excluded.

The remaining samples become the final calibration dataset.

---

## 16.13 Zone Dataset

After outlier removal, each interaction zone contains a validated collection of Feature Vectors.

Conceptually:

```
Top Left

FeatureVector₁

FeatureVector₂

...

FeatureVector₂₀
```

The exact number may be less than twenty if rejected samples are replaced during calibration.

---

## 16.14 Mean Feature Vector

The first statistical quantity computed for each zone is the Mean Feature Vector.

The mean represents the expected acoustic signature of that interaction zone.

For every feature dimension:

```
Mean = Average of all accepted samples
```

The resulting vector becomes the statistical center of the calibrated zone.

---

## 16.15 Covariance Matrix

The second quantity computed is the covariance matrix.

Unlike Euclidean distance, covariance accounts for:

- Feature variance
- Feature correlation
- Natural measurement spread

The covariance matrix describes the statistical "shape" of each interaction zone.

This information is fundamental to Mahalanobis classification.

---

## 16.16 Acceptance Threshold

Each zone receives an independent acceptance threshold.

Rather than using a universal distance threshold, Tapper derives thresholds from the calibration data.

Recommended strategy:

```
Threshold

=

Mean Distance

+

2 × Standard Deviation
```

This approach adapts naturally to the variability of each calibrated zone.

---

## 16.17 Calibration Quality

Once statistical models have been generated, Tapper evaluates the overall quality of the calibration.

Factors include:

- Intra-zone variance
- Inter-zone separation
- Sample consistency
- Number of rejected taps
- Signal-to-noise ratio

Calibration Quality shall be reported as a percentage.

Example:

```
Calibration Quality

96%

Excellent
```

---

## 16.18 Calibration Rating

The application shall classify calibration quality into five categories.

| Score | Rating |
|--------|---------|
| 95–100 | Excellent |
| 85–94 | Good |
| 70–84 | Acceptable |
| 50–69 | Marginal |
| Below 50 | Poor |

Poor calibrations should recommend repeating the process.

---

## 16.19 Persisted Calibration Profile

After successful calibration, Tapper stores a Zone Profile for every interaction zone.

Each profile contains:

- Zone Identifier
- Mean Feature Vector
- Covariance Matrix
- Acceptance Threshold
- Calibration Timestamp
- Device Identifier
- Algorithm Version

Raw audio recordings shall never be stored.

Raw Feature Vectors should be discarded after statistical model generation unless diagnostics mode is enabled.

---

## 16.20 Device Consistency

Calibration profiles are specific to the device on which they were created.

Changes in hardware characteristics may invalidate previously generated profiles.

Examples include:

- Different MacBook model
- Significant hardware repair
- Microphone replacement
- Chassis damage

Profiles shall not be shared across devices.

---

## 16.21 Recalibration

Users should be encouraged to recalibrate when:

- Recognition accuracy decreases
- Hardware changes
- Major software updates modify the recognition algorithm
- Environmental conditions change substantially
- A profile becomes corrupted

Recalibration replaces the previous statistical model entirely.

No information from earlier calibrations is reused.

---

## 16.22 Calibration Completion

Calibration is considered complete only when:

- All four zones have valid statistical models
- All thresholds have been computed
- Calibration quality exceeds the minimum acceptable rating
- Profiles have been successfully persisted

Only after these conditions are met shall Tapper enable runtime recognition.

The calibration phase concludes with the generation of a complete statistical representation of the user's device.

Subsequent runtime recognition operates exclusively on this statistical model without further learning or adaptation.

# 17. Mathematical Foundations

## 17.1 Purpose

The purpose of this section is to formally define the mathematical model used by the Tapper recognition engine.

Rather than relying on heuristic scoring or probabilistic machine learning models, Tapper performs statistical pattern recognition using deterministic multivariate analysis.

Each interaction zone is modeled as a multidimensional statistical distribution derived during calibration.

Runtime recognition consists of measuring how closely an incoming tap matches each calibrated distribution.

No adaptive learning occurs after calibration.

---

## 17.2 Mathematical Overview

For every interaction zone, calibration produces the following statistical model:

```
Zone Profile

↓

Mean Feature Vector (μ)

↓

Covariance Matrix (Σ)

↓

Acceptance Threshold (T)

↓

Metadata
```

Runtime recognition compares a candidate Feature Vector against each Zone Profile.

The comparison metric is the Mahalanobis Distance.

---

## 17.3 Feature Space

Every tap is represented as a point in a ten-dimensional feature space.

```
Feature Vector

x =

[
PeakAmplitude,

RMSEnergy,

SpectralCentroid,

SpectralBandwidth,

SpectralRollOff,

DominantFrequency,

ZeroCrossingRate,

AttackTime,

DecayTime,

SignalDuration

]
```

Each dimension corresponds to one measured acoustic property.

No feature weighting is applied manually.

Feature importance is learned statistically through the covariance matrix.

---

## 17.4 Mean Feature Vector

The Mean Feature Vector represents the expected acoustic signature of an interaction zone.

For a calibration dataset containing N accepted samples:

```
μ

=

(1/N)

Σ xᵢ
```

where

- μ is the Mean Feature Vector
- xᵢ is an individual Feature Vector
- N is the number of accepted calibration samples

The resulting vector defines the statistical center of the calibrated interaction zone.

---

## 17.5 Interpretation of the Mean

The Mean Feature Vector does not necessarily correspond to any single recorded tap.

Instead, it represents the average acoustic behavior observed during calibration.

Every runtime comparison is ultimately a comparison against this expected behavior.

---

## 17.6 Covariance Matrix

The covariance matrix describes how each feature varies relative to every other feature.

Unlike Euclidean distance, covariance captures:

- Feature variance
- Feature correlation
- Natural measurement spread

This allows the recognition engine to distinguish between:

- Normal variation
- Abnormal observations

without manually assigning feature weights.

---

## 17.7 Covariance Matrix Definition

For a calibration dataset containing N Feature Vectors:

```
Σ

=

1/(N−1)

Σ

(xᵢ−μ)

(xᵢ−μ)ᵀ
```

where

- Σ is the covariance matrix
- μ is the Mean Feature Vector

The resulting matrix has dimensions:

```
10 × 10
```

for Version 1.

---

## 17.8 Interpretation

Diagonal elements describe the variance of each feature.

Off-diagonal elements describe the correlation between pairs of features.

Example:

```
High Spectral Centroid

↓

Often accompanies

↓

Higher Dominant Frequency
```

This relationship is naturally captured by covariance.

---

## 17.9 Why Covariance Matters

Suppose two features always change together.

Treating them independently would effectively count the same information twice.

The covariance matrix prevents this by modeling feature relationships explicitly.

This greatly improves recognition accuracy.

---

## 17.10 Statistical Shape

Each calibrated interaction zone can be visualized as an ellipsoid in feature space.

```
            ○

        ○       ○

     ○             ○

        ○       ○

            ○
```

The center is the Mean Feature Vector.

The shape is determined by the covariance matrix.

Large variance produces wider ellipsoids.

Small variance produces tighter ellipsoids.

---

## 17.11 Runtime Observation

A newly detected tap produces a Feature Vector:

```
x
```

The recognition engine compares this vector against every calibrated interaction zone.

The objective is to determine:

> Which statistical distribution most likely generated this observation?

---

## 17.12 Similarity Metrics

Tapper supports several recognisers, all deterministic and all operating on the
canonical Feature Vector (ADR-015, ADR-016):

1. **Mahalanobis Distance** — the Version 1 metric, specified in §17.13 onwards.
2. **Distance-weighted k-Nearest Neighbour** — specified in §17.23, operating on
   the labelled samples stored in the calibration profile.
3. **Nearest Centroid** — specified in §17.24, also operating on the stored
   samples.

**Mahalanobis is the production recogniser.** The others are experimental and
are evaluated, never executed against: a benchmark result does not promote a
recogniser. Validation evaluates the full set defined in §17.25 on identical
trials so the choice can eventually be made from measured data rather than
assumption. Promotion is an explicit decision requiring hardware evidence.

Mahalanobis Distance shall remain available in all Version 1-compatible builds.

### 17.12.1 Mahalanobis Distance

Mahalanobis Distance is used as a similarity metric because, unlike Euclidean
distance, it accounts for:

- Feature scaling
- Feature correlation
- Statistical variance

This makes it particularly well suited to multivariate acoustic classification.

---

## 17.13 Mahalanobis Distance Equation

The Mahalanobis Distance is defined as:

```
D²

=

(x−μ)ᵀ

Σ⁻¹

(x−μ)
```

where

- x = candidate Feature Vector
- μ = Mean Feature Vector
- Σ⁻¹ = inverse covariance matrix

The square root of D² yields the Mahalanobis Distance.

---

## 17.14 Interpretation

Small distance:

```
Candidate closely resembles calibration.
```

Large distance:

```
Candidate differs significantly from calibration.
```

Distance therefore becomes a quantitative measure of similarity.

---

## 17.15 Why Not Euclidean Distance?

Euclidean distance assumes:

- identical feature variance
- independent features
- equal feature importance

These assumptions are false for tap recognition.

For example:

```
Peak Amplitude

↓

Small variance

Attack Time

↓

Large variance
```

Treating both equally produces poorer classification.

Mahalanobis naturally compensates for these differences.

---

## 17.16 Zone Ranking

During runtime:

Every Zone Profile computes one Mahalanobis Distance.

Example:

```
Top Left

↓

1.82

Top Right

↓

4.91

Bottom Left

↓

2.76

Bottom Right

↓

5.32
```

The smallest distance becomes the candidate recognition result.

---

## 17.17 Acceptance Threshold

Selecting the minimum distance alone is insufficient.

Even the "closest" zone may still represent a poor match.

Each calibrated zone therefore stores an independent acceptance threshold.

Recognition proceeds only if:

```
Distance

≤

Threshold
```

Otherwise the tap is classified as:

```
Unknown
```

---

## 17.18 Threshold Generation

Thresholds are derived during calibration.

Recommended formulation:

```
Threshold

=

Mean Distance

+

2 × Standard Deviation
```

This captures approximately 95% of naturally occurring calibration observations under near-normal distributions.

The multiplier may be adjusted through configuration if future testing indicates improved performance.

---

## 17.19 Confidence Score

Although classification is binary (accepted or rejected), Tapper computes an internal confidence score for diagnostics.

Confidence shall be derived from the ratio between:

- observed distance
- acceptance threshold

One possible formulation is:

```
Confidence

=

100

×

(

1

−

Distance / Threshold

)
```

The value is clamped to:

```
0%

↓

100%
```

This score is used exclusively for:

- Diagnostics
- Calibration feedback
- Recognition history
- User interface indicators

Confidence shall **never** influence the classification decision.

---

## 17.20 Statistical Assumptions

The recognition engine assumes:

- Calibration data reasonably represents future taps.
- Feature distributions are approximately continuous.
- Moderate covariance exists between several features.
- Natural tapping variation is significantly smaller than inter-zone variation.

These assumptions are validated through calibration quality assessment.

---

## 17.21 Numerical Stability

To ensure stable statistical computations:

- Covariance matrices shall remain positive definite.
- Singular covariance matrices shall be rejected.
- Matrix inversion failures shall invalidate the affected calibration profile.
- Floating-point operations shall use 64-bit precision.

Regularization may be applied if required to improve numerical stability, provided it remains deterministic and consistently applied across all calibration profiles.

---

## 17.22 Summary

The mathematical model described in this section forms the core of Tapper's recognition engine.

Rather than comparing raw waveforms or relying on learned neural representations, Tapper performs deterministic multivariate statistical classification.

Every interaction zone is represented by:

- A Mean Feature Vector
- A Covariance Matrix
- An Acceptance Threshold

Every runtime tap is converted into a Feature Vector and evaluated using Mahalanobis Distance.

This approach provides:

- Deterministic recognition
- High interpretability
- Statistical robustness
- Low computational complexity
- Excellent real-time performance

The mathematical model established here serves as the foundation for the runtime Classification Engine described in the following section.

---

## 17.23 Distance-Weighted k-Nearest Neighbour

### 17.23.1 Purpose

The k-Nearest Neighbour recogniser classifies an observation against the
labelled samples collected during calibration, rather than against a
distributional summary of them. It estimates no parameters, represents zones
that the user taps in more than one way, and admits new samples in constant
time (ADR-015).

### 17.23.2 Feature Space

Observations and stored samples shall both be transformed by the calibration
profile's global normalization parameters (§15.7) before any distance is
computed. Without this, features measured in hertz would dominate features
measured in normalized amplitude.

### 17.23.3 Distance

Euclidean distance in the normalized feature space:

```
d(x, s) = sqrt( Σ (xᵢ − sᵢ)² )
```

### 17.23.4 Neighbour Selection

The k nearest stored samples are selected, with k = 3 by default. Ties in
distance shall be broken by the canonical zone order defined in §18.11, so that
selection is deterministic.

### 17.23.5 Weighted Vote

Each selected neighbour votes for its label with weight:

```
w = 1 / (d + ε)
```

where ε is a small positive constant preventing division by zero. The predicted
zone is the label with the greatest total weight. Ties in total weight shall be
broken by the canonical zone order.

### 17.23.6 Confidence

Confidence is the winning label's share of the total vote weight, expressed as a
percentage:

```
confidence = 100 × (winning weight / total weight)
```

Confidence is diagnostic. It shall never alter the classification decision.

### 17.23.7 Rejection Policy

Raw nearest-neighbour classification always returns a label. To satisfy the
fail-safe principle (ADR-009), a recognition shall be accepted only when both
conditions hold:

1. **Distance acceptance.** The distance to the nearest neighbour of the winning
   zone shall not exceed that zone's acceptance radius, derived during
   calibration as `mean + k·σ` of the leave-one-out nearest-neighbour distances
   within that zone. This mirrors the threshold formulation of §17.18 and
   introduces no new constant.

2. **Vote margin.** The winning zone's vote weight shall exceed the runner-up's
   by at least the configured ambiguity margin, expressed as a fraction of the
   total weight.

If the first condition fails the result is `unknown`; if the second fails the
result is `ambiguous`. In both cases no command is executed.

## 17.24 Nearest Centroid

### 17.24.1 Purpose

The Nearest Centroid recogniser assigns an observation to the zone whose mean
sample is closest in the normalized feature space. It is included in the
benchmark set (§17.25) as the simplest recogniser that uses the stored samples,
and therefore as the baseline against which any more elaborate recogniser must
justify its complexity.

### 17.24.2 Model

For each zone, the centroid is the mean of that zone's stored samples:

```
c = (1/n) Σ sᵢ
```

Distances are Euclidean, in the normalized feature space of §17.23.2. Unlike
Mahalanobis, no covariance is estimated, so no regularization is required and
no matrix is inverted.

### 17.24.3 Acceptance Radius

Each zone's acceptance radius is derived from the spread of its own samples
about its centroid, using the threshold formulation of §17.18:

```
r = mean(dᵢ) + k · σ(dᵢ)      where dᵢ = ‖sᵢ − c‖
```

This introduces no new constant: `k` is the existing threshold multiplier.

### 17.24.4 Rejection Policy

A recognition is accepted only when both conditions hold, mirroring §17.23.7:

1. **Distance acceptance.** The distance to the winning centroid shall not
   exceed that zone's acceptance radius.
2. **Separation margin.** The runner-up centroid shall be farther than the
   winner by at least the profile's ambiguity margin, which is an absolute
   distance and therefore directly comparable here.

If the first condition fails the result is `unknown`; if the second fails the
result is `ambiguous`.

### 17.24.5 Confidence

Confidence is reported on the same scale as §17.17, as a function of the
winning distance relative to the acceptance radius. It is diagnostic and shall
never alter the decision.

---

## 17.25 Recogniser Benchmark

### 17.25.1 Purpose

The benchmark evaluates several recognisers on identical observations so that
the production recogniser can be chosen from measured hardware performance
(ADR-016). It is a **measurement facility**. Its results are reported and never
acted upon: no recogniser is selected, promoted, or disabled by a benchmark
outcome.

### 17.25.2 Membership

The Version 1 benchmark set is:

| Identifier | Specification |
|---|---|
| `mahalanobis` | §17.13 |
| `nearest-centroid` | §17.24 |
| `knn-1` | §17.23 with k = 1 |
| `knn-3-weighted` | §17.23 with k = 3 |
| `knn-5-weighted` | §17.23 with k = 5 |

At k = 1 the weighted vote of §17.23.5 is degenerate — a single neighbour holds
the entire vote weight — so the vote-margin condition of §17.23.7 is always
satisfied and only distance acceptance governs rejection. This is a property of
the configuration, not a defect, and shall be stated wherever `knn-1` results
are reported.

### 17.25.3 Identical Input

Every recogniser in the set shall receive the same Feature Vector instance and
the same normalization parameters, taken from the candidate that production
classified. Any difference between their outputs is then attributable to the
recogniser alone.

### 17.25.4 Model Preparation

A recogniser shall be constructed against the calibration profile once, before
measurement begins, and shall then classify many observations. Quantities
derivable from the profile — centroids, radii, inverted covariances — shall be
computed during construction, so reported latency measures classification only.

### 17.25.5 Reported Metrics

For each recogniser the benchmark shall report:

- overall accuracy;
- per-zone accuracy;
- a confusion matrix of expected against reported zone;
- unknown rate, over evaluated taps;
- false negatives, being taps yielding no recognition;
- false positives, being recognitions during idle recording;
- classification latency.

### 17.25.6 Acceptance Instrumentation

For every evaluated observation the benchmark shall record the distance
computed, the acceptance radius tested against, the difference between them,
whether the observation was accepted, and the reported confidence.

The acceptance radius formulations of §17.23.6 and §17.24.3 are analytical
choices, not measured ones. This instrumentation exists so that a later
decision about them can be evidence-based. Recording it changes no threshold.

---

# 18. Classification Engine

## 18.1 Purpose

The Classification Engine is responsible for determining which calibrated interaction zone most closely matches an incoming tap.

The engine operates exclusively on the statistical models generated during calibration.

No additional learning, adaptation, or parameter tuning occurs during runtime.

For every validated Feature Vector, the Classification Engine shall produce exactly one of the following outcomes:

- Recognized Interaction Zone
- Unknown
- Rejected

---

## 18.2 Inputs

The Classification Engine receives:

### Runtime Feature Vector

The normalized Feature Vector generated from the current tap.

```
x
```

---

### Zone Profiles

Each calibrated interaction zone provides:

- Mean Feature Vector (μ)
- Covariance Matrix (Σ)
- Acceptance Threshold (T)

For Version 1:

```
Zone Profile

Top Left

Top Right

Bottom Left

Bottom Right
```

---

### Runtime Metadata

Additional runtime information includes:

- Timestamp
- Cooldown State
- Recognition State
- Diagnostics Mode

These values do **not** influence statistical classification but are required for runtime decision making.

---

## 18.3 Outputs

The Classification Engine returns a Recognition Result.

```
RecognitionResult
{
    Zone

    Distance

    Threshold

    Confidence

    Accepted

    Timestamp
}
```

If recognition fails, the Zone shall be reported as:

```
Unknown
```

---

# 18.4 Recognition Pipeline

For every validated tap, the runtime recognition process follows the sequence below.

```
Feature Vector

↓

Normalize

↓

Compare with Zone 1

↓

Compare with Zone 2

↓

Compare with Zone 3

↓

Compare with Zone 4

↓

Rank Distances

↓

Threshold Validation

↓

Cooldown Validation

↓

Recognition Result
```

Every stage must complete successfully before recognition proceeds.

---

# 18.5 Distance Computation

The candidate Feature Vector is compared against every calibrated interaction zone.

For each zone:

```
Distance

=

Mahalanobis

(

FeatureVector,

ZoneProfile

)
```

This produces one distance value per interaction zone.

Example:

| Zone | Distance |
|------|---------:|
| Top Left | 1.84 |
| Top Right | 5.63 |
| Bottom Left | 3.17 |
| Bottom Right | 4.92 |

---

# 18.6 Candidate Ranking

The resulting distances are sorted in ascending order.

Example

```
Top Left

↓

1.84

Bottom Left

↓

3.17

Bottom Right

↓

4.92

Top Right

↓

5.63
```

The smallest distance becomes the Primary Candidate.

Remaining zones become Secondary Candidates.

---

# 18.7 Candidate Validation

Selecting the nearest zone alone is insufficient.

The Primary Candidate must satisfy all validation criteria.

Validation includes:

- Distance below threshold
- Feature Vector valid
- Recognition not in cooldown
- Runtime state permits execution

Failure of any validation step immediately rejects the candidate.

---

# 18.8 Threshold Validation

Each interaction zone possesses an independently derived acceptance threshold.

Validation rule:

```
If

Distance

≤

Zone Threshold

↓

Accept

Else

↓

Reject
```

Thresholds are never shared between zones.

---

# 18.9 Ambiguous Recognition

Occasionally two interaction zones may produce very similar distances.

Example

| Zone | Distance |
|------|---------:|
| Top Left | 2.11 |
| Bottom Left | 2.18 |

Although both distances satisfy their thresholds, the statistical separation is extremely small.

This introduces ambiguity.

---

## 18.10 Ambiguity Detection

An ambiguity condition exists whenever the distance difference between the best and second-best candidates falls below the configured ambiguity margin.

Conceptually:

```
Best Distance

≈

Second Distance

↓

Ambiguous
```

Ambiguous taps shall **not** execute commands.

Instead they shall be classified as:

```
Unknown
```

This conservative strategy minimizes false positives.

---

## 18.11 Tie Breaking

True mathematical ties are extremely unlikely.

However, implementations shall define deterministic behavior.

If two zones produce identical distances:

Priority order:

```
Top Left

↓

Top Right

↓

Bottom Left

↓

Bottom Right
```

This rule exists solely to guarantee deterministic execution.

In practice, floating-point precision makes exact ties nearly impossible.

---

## 18.12 Unknown Classification

A tap shall be classified as Unknown whenever:

- No zone satisfies its threshold.
- Multiple zones satisfy thresholds but are ambiguous.
- Feature Vector validation fails.
- Statistical model is invalid.

Unknown events are logged but never trigger user actions.

---

## 18.13 Confidence Computation

Confidence represents the quality of the accepted match.

Confidence is derived after successful threshold validation.

General characteristics:

Small Distance

↓

High Confidence

Large Distance

↓

Lower Confidence

Confidence is expressed as:

```
0%

↓

100%
```

Confidence is diagnostic only.

It never changes the classification outcome.

---

## 18.14 Cooldown Validation

Before command execution, Tapper verifies that the cooldown interval has expired.

```
Accepted

↓

Cooldown Active?

↓

Yes

↓

Ignore

↓

No

↓

Execute
```

Cooldown prevents duplicate recognition from a single physical tap.

---

## 18.15 Recognition Result

After successful validation, the Classification Engine produces a Recognition Result.

```
RecognitionResult

{

Zone

Confidence

Distance

Threshold

Accepted

Timestamp

}
```

This object becomes the canonical output of the recognition engine.

---

## 18.16 Execution Decision

Recognition decisions follow the deterministic flow below.

```
Feature Vector

↓

Distance Calculation

↓

Rank Zones

↓

Best Candidate

↓

Threshold Check

↓

Ambiguity Check

↓

Cooldown Check

↓

Execute

↓

Diagnostics
```

Every recognition follows this sequence.

No shortcuts or alternative execution paths are permitted.

---

## 18.17 Runtime Guarantees

The Classification Engine guarantees:

- Constant execution time
- Deterministic output
- No adaptive learning
- No randomness
- No dependence on historical taps
- No cloud processing
- Constant memory usage

Recognition of one tap shall never influence recognition of future taps.

---

## 18.18 Failure Conditions

Recognition shall terminate immediately if:

- Calibration profile missing
- Covariance matrix invalid
- Matrix inversion failure
- Invalid Feature Vector
- Runtime state invalid
- Cooldown active

In each case:

```
Recognition

↓

Rejected

↓

Diagnostics Logged

↓

Return Listening
```

---

## 18.19 Design Rationale

The Classification Engine intentionally separates three distinct responsibilities:

1. Statistical Comparison
2. Decision Validation
3. Command Execution

This modular architecture provides several advantages:

- Easier debugging
- Improved explainability
- Independent testing
- Future extensibility
- Deterministic behavior

Future recognition algorithms may replace the statistical comparison stage without altering the surrounding execution pipeline, provided they preserve the interfaces defined in this specification.

The Classification Engine concludes the recognition phase and produces a validated Recognition Result that is subsequently passed to the Action Dispatch subsystem for execution.

# 19. Noise Rejection

## 19.1 Purpose

The objective of the Noise Rejection Engine is to eliminate acoustic events that resemble intentional taps but originate from unrelated environmental or mechanical sources.

Noise rejection is critical to maintaining a low false-positive rate.

Unlike the Classification Engine, which determines *where* a tap occurred, the Noise Rejection Engine determines *whether the event should be considered a tap at all.*

Every candidate event shall pass through the Noise Rejection Engine before classification.

---

## 19.2 Design Goals

The Noise Rejection Engine shall:

- Reject common environmental sounds
- Reject accidental physical interactions
- Preserve intentional taps
- Operate deterministically
- Introduce negligible computational overhead
- Avoid machine learning or adaptive filtering

False positives are considered more harmful than false negatives.

When uncertainty exists, the engine shall reject the event.

---

## 19.3 Noise Sources

The recognition engine shall explicitly consider the following classes of unwanted events.

### Environmental

- Human speech
- Music
- Television
- HVAC systems
- Ceiling fans
- Rain
- Road traffic

---

### Mechanical

- Keyboard typing
- Trackpad clicks
- Desk vibration
- Laptop movement
- Charger insertion
- Lid closure
- Object impact
- Mouse clicks

---

### Electrical

- Microphone artifacts
- Quantization noise
- Electrical interference
- Clipped samples

---

## 19.4 Multi-Stage Rejection

Noise rejection is not a single operation.

Instead, rejection occurs throughout the recognition pipeline.

```
Audio

↓

Filtering

↓

Candidate Validation

↓

Feature Validation

↓

Noise Rejection

↓

Classification
```

Each stage removes progressively more sophisticated false candidates.

---

# 19.5 Low-Energy Rejection

Candidates whose RMS Energy falls below the minimum calibrated energy threshold shall be rejected.

These events typically correspond to:

- Ambient room noise
- Fan noise
- Microphone hiss
- Air conditioning

Such events rarely exhibit the transient impulse characteristics of intentional taps.

---

# 19.6 Duration Rejection

Intentional taps are extremely short-lived.

Candidates exceeding the configured duration limit shall be rejected.

Examples include:

- Sliding fingers
- Laptop movement
- Continuous vibration
- Speech

Duration is evaluated using the Signal Duration feature.

A censored duration (§14.13.5) shall never be compared against the duration
limit: the event outlasted the observation window, so its total duration is
unknown, not excessive (ADR-017 §4). Only an uncensored duration may cause
rejection for exceeding the limit.

The limit is **derived during calibration** from the user's own taps
(ADR-017 §1, stage 5) and stored in the calibration profile. During
calibration itself no upper duration limit applies, because the limit does not
exist until the taps it is derived from have been measured. The derivation is
Tukey's far-out fence over the Signal Duration of every accepted calibration
sample:

```
MaximumDuration = max( Q3 + 3 * (Q3 - Q1), 25 ms )
```

The 25 ms floor is the previous fixed limit, so a derived limit is never
stricter than the old one. Censored durations participate in the quartiles at
full weight, as §14.13.5 requires of statistics.

*Basis.* Hardware calibration at CP-2 (2026-10-26, MacBook Air) measured a
median decay time constant of 16.3 ms (p10 9.4 ms, p90 32.5 ms), so a median
tap fades by 20 dB in about 37 ms. The fixed 25 ms limit rejected 16% of
natural taps.

---

# 19.7 Frequency Rejection

Candidate events dominated by frequencies outside the calibrated tap spectrum shall be rejected.

Typical examples include:

Low Frequency

- Desk vibration
- Footsteps
- Mechanical rumble

High Frequency

- Electrical interference
- Digital artifacts
- Sensor noise

The Butterworth filter removes most of these components before feature extraction.

---

# 19.8 Typing Rejection

Keyboard typing produces acoustic impulses similar to taps.

However, typing exhibits distinct characteristics.

Compared with intentional taps:

- Lower resonance consistency
- Different dominant frequencies
- Longer event sequences
- Rapid repetitive timing

Typing events generally fail statistical classification.

No keyboard-specific classifier is required.

---

# 19.9 Trackpad Rejection

Trackpad clicks generate highly localized impulses.

Their spectral signatures differ substantially from chassis taps.

Typical properties include:

- Short duration
- Different resonance profile
- Lower bandwidth
- Alternative dominant frequency

Trackpad clicks are rejected naturally through statistical distance.

---

# 19.10 Speech Rejection

Human speech produces:

- Long-duration signals
- Multiple harmonics
- Slowly varying energy
- Broad temporal structure

Speech fails candidate validation because it lacks the impulsive transient required for tap recognition.

---

# 19.11 Laptop Movement

Moving the laptop often produces broad, low-frequency mechanical vibrations.

Examples include:

- Picking up the laptop
- Sliding across a desk
- Rotating the chassis

These events generally exhibit:

- Long attack times
- Long decay
- Extended duration

Such candidates shall be rejected.

---

# 19.12 Charger Insertion

Connecting or disconnecting the charging cable may generate mechanical vibrations.

These events typically:

- Originate near one corner
- Produce low-frequency impulses
- Lack calibrated resonance characteristics

Statistical comparison should reject these observations.

---

# 19.13 Lid Closure

Closing the display generates a high-energy impulse.

However, lid closure differs from intentional taps in several ways:

- Very high energy
- Long resonance
- Large bandwidth
- Distinct spectral profile

These events shall fail statistical validation.

---

# 19.14 Continuous Vibration

Continuous vibrations include:

- Washing machines
- Vehicle movement
- Loud speakers
- Construction activity

Such events exhibit:

- Sustained energy
- Poor transient structure
- High signal duration

Continuous vibration shall never produce a valid tap candidate.

---

# 19.15 Double Impulse Rejection

Occasionally users may accidentally produce two nearly simultaneous taps.

Example:

```
Tap

↓

15 ms

↓

Second Tap
```

These events may overlap within a single analysis window.

If multiple dominant peaks are detected within one candidate window, the candidate may be rejected as ambiguous.

Future versions may explicitly recognize multi-tap gestures.

Version 1 treats these events conservatively.

---

# 19.16 Clipping Rejection

If the incoming waveform exceeds the valid recording range, clipping occurs.

Clipped signals distort spectral characteristics and invalidate feature extraction.

Any clipped candidate shall be discarded before classification.

No attempt shall be made to reconstruct clipped waveforms.

---

# 19.17 Noise Floor Monitoring

The recognition engine continuously estimates the ambient noise floor.

This estimate supports:

- Candidate validation
- Weak signal rejection
- Diagnostics

The runtime noise floor shall **not** modify calibrated statistical models.

It is used only for event validation.

---

# 19.18 Rejection Logging

Every rejected candidate shall include a rejection reason.

A declined decay estimate (§14.13.6) is logged as its own reason, *Decay Not
Measurable*, distinct from a duration outside the configured limits.

Examples:

```
Rejected

Reason:

Low Energy
```

```
Rejected

Reason:

Cooldown Active
```

```
Rejected

Reason:

Invalid Feature Vector
```

```
Rejected

Reason:

High Statistical Distance
```

Logging rejection reasons greatly improves diagnostics and troubleshooting.

---

# 19.19 Design Philosophy

The Noise Rejection Engine intentionally uses multiple conservative validation stages rather than relying on a single threshold.

Each rejection stage removes a different class of invalid events.

This layered approach provides significantly greater robustness than any individual heuristic while maintaining deterministic behavior.

The engine is designed such that most environmental sounds are rejected before statistical classification, allowing the Classification Engine to operate only on high-quality candidate taps.

# 20. Tap Quality System

## 20.1 Purpose

The Tap Quality System provides a deterministic assessment of how well an individual tap conforms to the expected characteristics of an intentional calibration or runtime tap.

Unlike the Classification Engine, which determines the most likely interaction zone, the Tap Quality System evaluates the intrinsic quality of the acoustic event itself.

Tap Quality is intended for:

- Calibration feedback
- Diagnostics
- Recognition history
- User guidance
- Performance analysis

Tap Quality shall **never** influence runtime classification decisions.

Classification remains solely dependent on the statistical model described in the preceding sections.

---

## 20.2 Design Philosophy

Users often struggle to understand why calibration succeeds or fails.

Traditional feedback such as:

```
Tap Recorded
```

provides little useful information.

Instead, Tapper shall evaluate every accepted tap and present meaningful feedback describing its quality.

Example:

```
Tap Quality

96%

Excellent
```

This approach allows users to naturally improve their tapping consistency without requiring technical knowledge of the underlying algorithm.

---

## 20.3 Separation of Responsibilities

The Tap Quality System operates independently from the Classification Engine.

Classification answers the question:

> Which interaction zone produced this tap?

Tap Quality answers a different question:

> How well does this tap resemble a clean, intentional tap?

Maintaining this separation prevents quality assessment from affecting recognition accuracy.

---

## 20.4 Inputs

The Tap Quality System evaluates the following information:

- Peak Amplitude
- RMS Energy
- Signal-to-Noise Ratio
- Attack Time
- Decay Time
- Signal Duration
- Clipping Detection
- Statistical Distance
- Candidate Validation Results

No additional machine learning or heuristic scoring is permitted.

---

## 20.5 Quality Metrics

Quality is derived from multiple independent metrics.

### Signal Strength

Measures whether the tap generated sufficient acoustic energy.

Weak taps reduce quality.

---

### Signal-to-Noise Ratio

Compares tap energy against the ambient noise floor.

Higher SNR results in higher quality.

---

### Statistical Consistency

Measures how closely the tap resembles the calibrated statistical model.

Lower Mahalanobis Distance corresponds to higher quality.

---

### Temporal Characteristics

Evaluates:

- Attack Time
- Decay Time
- Signal Duration

Intentional taps should exhibit a rapid onset followed by a natural resonance decay.

---

### Signal Integrity

Quality decreases if:

- Clipping occurs
- Multiple impulses are detected
- Invalid samples exist
- Numerical instability is observed

---

## 20.6 Quality Score

Each accepted tap receives a numerical quality score.

Range:

```
0

↓

100
```

The exact weighting of each metric is implementation-defined but shall remain deterministic.

The weighting must remain identical across all recognition sessions.

---

## 20.7 Quality Levels

The numerical score shall be mapped to one of five quality categories.

| Score | Rating |
|--------|---------|
| 95–100 | Excellent |
| 85–94 | Good |
| 70–84 | Acceptable |
| 50–69 | Marginal |
| Below 50 | Poor |

These ranges may be refined following empirical testing but shall remain fixed within a given algorithm version.

---

## 20.8 Calibration Usage

During calibration, Tap Quality provides immediate feedback after every accepted tap.

Example:

```
Tap 8 / 20

Quality

Excellent

97%
```

or

```
Tap 12 / 20

Quality

Marginal

58%

Suggestion

Tap slightly firmer.
```

This feedback improves calibration consistency while reducing user frustration.

---

## 20.9 Runtime Diagnostics

During normal recognition, Tap Quality is recorded for diagnostics only.

Example Recognition Log:

```
Timestamp

14:52:11.324

Zone

Top Left

Confidence

94%

Tap Quality

Excellent

98%
```

This information assists in troubleshooting recognition issues without affecting runtime behavior.

---

## 20.10 Rejected Candidates

Candidates rejected before classification do not receive a Tap Quality score.

Instead, the diagnostics engine records the rejection reason.

Example:

```
Rejected

Reason

Low Energy
```

or

```
Rejected

Reason

Cooldown Active
```

This distinction prevents confusion between poor-quality taps and events that never qualified as valid candidates.

---

## 20.11 Quality History

When diagnostics are enabled, Tapper may maintain a rolling history of recent Tap Quality scores.

This history enables users to observe trends such as:

- Increasing consistency
- Decreasing signal quality
- Environmental interference
- Hardware degradation

Historical quality data shall not influence runtime recognition.

---

## 20.12 Engineering Constraints

The Tap Quality System shall satisfy the following constraints:

- Deterministic
- Constant-time execution
- No dynamic learning
- No modification of calibration profiles
- No modification of runtime thresholds
- No influence on classification decisions

Its purpose is observational rather than predictive.

---

## 20.13 Future Extensions

Future algorithm versions may extend the Tap Quality System with additional metrics, including:

- Finger placement consistency
- Resonance stability
- Environmental noise classification
- Per-zone calibration quality
- Long-term trend analysis

Such enhancements shall remain diagnostic in nature and must not alter the deterministic recognition pipeline.

---

## 20.14 Summary

The Tap Quality System provides a deterministic assessment of the acoustic quality of individual tap events.

By separating quality evaluation from statistical classification, Tapper provides meaningful feedback to users while preserving the integrity of the recognition engine.

This subsystem significantly improves calibration usability, diagnostics, and overall user confidence without introducing additional complexity into the recognition algorithm.

# 21. Runtime State Machine

## 21.1 Purpose

The Runtime State Machine defines the operational behavior of the Tapper recognition engine.

Rather than executing recognition logic through scattered conditional statements, Tapper models the recognition process as a deterministic finite-state machine (FSM).

At any point in time, the engine shall occupy exactly one runtime state.

State transitions occur only in response to well-defined events.

---

## 21.2 Design Goals

The Runtime State Machine shall provide:

- Deterministic execution
- Clear separation of responsibilities
- Predictable transitions
- Simplified debugging
- Constant-time state changes
- Robust error recovery

The state machine shall never enter undefined states.

Every transition must have an explicitly defined source and destination.

---

## 21.3 Runtime States

Version 1 defines the following runtime states:

```
Idle

Listening

Candidate Detection

Feature Extraction

Classification

Validation

Command Execution

Cooldown

Error
```

Only one state may be active at any given time.

---

## 21.4 State Overview

```
             ┌──────────┐
             │   Idle   │
             └────┬─────┘
                  │
                  ▼
          ┌──────────────┐
          │  Listening   │
          └──────┬───────┘
                 │
      Candidate Detected
                 │
                 ▼
      ┌──────────────────┐
      │Candidate Detection│
      └─────────┬─────────┘
                ▼
      ┌──────────────────┐
      │Feature Extraction│
      └─────────┬─────────┘
                ▼
      ┌──────────────────┐
      │ Classification   │
      └─────────┬─────────┘
                ▼
      ┌──────────────────┐
      │   Validation     │
      └─────────┬─────────┘
        Accepted│Rejected
                │
     ┌──────────┴──────────┐
     ▼                     ▼
┌──────────────┐     ┌─────────────┐
│Command Execute│     │ Listening   │
└──────┬────────┘     └─────────────┘
       ▼
┌──────────────┐
│  Cooldown    │
└──────┬───────┘
       ▼
┌──────────────┐
│ Listening    │
└──────────────┘
```

Any unrecoverable failure transitions to the **Error** state.

---

## 21.5 Idle State

### Purpose

The Idle state represents an inactive recognition engine.

Recognition has not yet begun.

Typical conditions include:

- Application startup
- Microphone unavailable
- Permissions pending
- Calibration missing

### Entry Conditions

- Application launched
- Recognition disabled

### Exit Conditions

- Initialization completed
- Audio pipeline started

---

## 21.6 Listening State

The Listening state is the normal operating state.

During Listening:

- Audio stream remains active
- Circular buffer continues updating
- Noise floor monitoring continues
- Candidate detection remains enabled

No classification occurs while no candidate exists.

The engine spends the majority of its runtime in this state.

---

## 21.7 Candidate Detection State

This state begins immediately after a transient acoustic event exceeds the detection threshold.

Operations include:

- Window extraction
- Candidate validation
- Peak verification
- Signal integrity checks

If validation fails:

```
Candidate Detection

↓

Listening
```

No additional processing occurs.

---

## 21.8 Feature Extraction State

A validated candidate enters Feature Extraction.

Operations performed:

- FFT
- Spectral analysis
- Time-domain analysis
- Feature calculation
- Feature vector construction

Successful completion produces one immutable Feature Vector.

Failure immediately returns to Listening.

---

## 21.9 Classification State

The Classification state performs statistical comparison.

Operations:

- Normalize Feature Vector
- Compute Mahalanobis Distance
- Compare against all Zone Profiles
- Rank candidates

No execution decisions occur in this state.

Its sole responsibility is statistical evaluation.

---

## 21.10 Validation State

The Validation state determines whether the classification result should be accepted.

Validation includes:

- Threshold verification
- Ambiguity detection
- Feature validation
- Cooldown eligibility

Possible outcomes:

```
Accepted

↓

Command Execution
```

or

```
Rejected

↓

Listening
```

---

## 21.11 Command Execution State

This state executes the action associated with the recognized interaction zone.

Typical operations include:

- Trigger shortcut
- Send application event
- Execute command
- Log recognition

Execution must be atomic.

Once execution completes successfully, the engine immediately enters Cooldown.

---

## 21.12 Cooldown State

The Cooldown state prevents duplicate recognition caused by residual chassis vibration or repeated acoustic reflections.

During Cooldown:

- Audio continues streaming
- Candidate events are ignored
- Diagnostics remain active

Cooldown duration is configurable.

Default implementation:

```
100 ms
```

After expiration:

```
Cooldown

↓

Listening
```

---

## 21.13 Error State

The Error state represents unrecoverable runtime failures.

Possible causes include:

- Audio engine failure
- Invalid calibration profile
- Matrix inversion failure
- DSP initialization failure
- Permission revocation

Recognition is suspended while the engine remains in Error.

---

## 21.14 Error Recovery

Recovery depends upon the failure type.

Recoverable errors:

- Microphone interruption
- Temporary audio failure

Recovery:

```
Error

↓

Reinitialize

↓

Listening
```

Non-recoverable errors require user intervention.

Examples:

- Missing calibration
- Invalid profile
- Corrupted statistical model

---

## 21.15 State Transition Table

| Current State | Event | Next State |
|--------------|-------|------------|
| Idle | Initialization Complete | Listening |
| Listening | Candidate Detected | Candidate Detection |
| Candidate Detection | Candidate Valid | Feature Extraction |
| Candidate Detection | Candidate Invalid | Listening |
| Feature Extraction | Success | Classification |
| Feature Extraction | Failure | Listening |
| Classification | Complete | Validation |
| Validation | Accepted | Command Execution |
| Validation | Rejected | Listening |
| Command Execution | Complete | Cooldown |
| Cooldown | Timer Expired | Listening |
| Any State | Fatal Error | Error |

This table represents the canonical runtime behavior.

---

## 21.16 State Invariants

Each runtime state maintains specific invariants.

Examples:

### Listening

- Audio stream active
- Buffer updating
- No active candidate

### Classification

- Valid Feature Vector
- Valid calibration profile
- Immutable runtime data

### Cooldown

- Timer active
- Command already executed
- Recognition temporarily disabled

Maintaining these invariants simplifies debugging and testing.

---

## 21.17 Deterministic Execution

The Runtime State Machine guarantees:

- One active state
- Explicit transitions
- No hidden side effects
- No asynchronous state mutation
- Constant memory usage

Given identical inputs, the engine shall always traverse the same sequence of states.

---

## 21.18 Concurrency Considerations

Although audio acquisition occurs continuously, recognition processing shall behave as a single logical execution pipeline.

Only one candidate tap may be processed at any given time.

If a new candidate is detected while another candidate is being processed, it shall be ignored until the engine returns to the Listening state.

This simplifies implementation and prevents race conditions without affecting normal recognition performance.

---

## 21.19 Diagnostics

When diagnostics mode is enabled, every state transition shall be recorded.

Example:

```
14:52:11.324

Listening

↓

Candidate Detection

↓

Feature Extraction

↓

Classification

↓

Validation

↓

Command Execution

↓

Cooldown

↓

Listening
```

These logs provide valuable insight into runtime behavior and facilitate debugging of recognition issues.

---

## 21.20 Summary

The Runtime State Machine provides the operational framework for the Tapper recognition engine.

By explicitly defining every state, transition, and recovery path, the engine achieves deterministic execution, simplified debugging, and predictable runtime behavior.

The following section builds upon this state machine by defining the complete decision logic used during runtime recognition.

# 22. Runtime Decision Tree

## 22.1 Purpose

The Runtime Decision Tree defines the deterministic decision-making process followed by the recognition engine after an acoustic event has been detected.

Whereas the Runtime State Machine specifies *when* operations occur, the Decision Tree specifies *how decisions are made*.

Every candidate event follows exactly one path through this decision tree.

The decision process shall contain no randomization, probabilistic branching, or adaptive behavior.

---

## 22.2 Design Objectives

The Runtime Decision Tree shall satisfy the following objectives:

- Deterministic execution
- Minimal decision latency
- Clearly defined rejection paths
- Single execution path per candidate
- Consistent behavior across all devices
- Easy debugging and verification

Given identical inputs, the engine shall always reach the same outcome.

---

## 22.3 High-Level Decision Flow

The complete runtime decision process is illustrated below.

```
Audio Event

↓

Candidate Detection

↓

Candidate Validation

↓

Feature Extraction

↓

Feature Vector Validation

↓

Statistical Classification

↓

Threshold Validation

↓

Ambiguity Detection

↓

Cooldown Check

↓

Execute Action

↓

Return to Listening
```

Failure at any stage immediately terminates processing for the current candidate.

---

## 22.4 Stage 1 — Candidate Detection

The first decision determines whether the incoming waveform represents a potential tap.

Decision Criteria:

- Energy above detection threshold
- Valid transient
- Correct signal duration
- Candidate window available

Decision:

```
Candidate Detected?

        │
   ┌────┴────┐
   │         │
 Yes        No
   │         │
   ▼         ▼
Continue   Listening
```

---

## 22.5 Stage 2 — Candidate Validation

The candidate undergoes basic integrity checks.

Validation includes:

- No clipping
- Valid waveform
- Peak detected
- Acceptable signal duration
- Minimum SNR

Decision:

```
Candidate Valid?

        │
   ┌────┴────┐
   │         │
 Yes        No
   │         │
   ▼         ▼
Feature    Reject
Extraction
```

Candidates failing validation are discarded immediately.

---

## 22.6 Stage 3 — Feature Extraction

The DSP pipeline computes the complete Feature Vector.

Required operations:

- FFT
- Spectral analysis
- Time-domain analysis
- Feature calculation
- Feature vector assembly

Decision:

```
Feature Extraction Successful?

        │
   ┌────┴────┐
   │         │
 Yes        No
   │         │
   ▼         ▼
Continue   Reject
```

Feature extraction failures are considered non-recoverable for the current candidate.

---

## 22.7 Stage 4 — Feature Vector Validation

The Feature Vector is verified before statistical comparison.

Validation includes:

- No NaN values
- No infinite values
- Correct dimensionality
- Valid numerical ranges

Decision:

```
Feature Vector Valid?

        │
   ┌────┴────┐
   │         │
 Yes        No
   │         │
   ▼         ▼
Classify   Reject
```

Invalid vectors shall never enter the Classification Engine.

---

## 22.8 Stage 5 — Statistical Classification

The validated Feature Vector is compared against every calibrated interaction zone.

Operations:

- Compute Mahalanobis Distance
- Rank all distances
- Select nearest candidate

Example:

| Zone | Distance |
|------|---------:|
| Top Left | 1.63 |
| Top Right | 5.42 |
| Bottom Left | 2.91 |
| Bottom Right | 4.76 |

The smallest distance becomes the Primary Candidate.

---

## 22.9 Stage 6 — Threshold Validation

The Primary Candidate must satisfy its zone-specific acceptance threshold.

Decision Rule:

```
Distance

≤

Threshold ?
```

Decision:

```
Within Threshold?

        │
   ┌────┴────┐
   │         │
 Yes        No
   │         │
   ▼         ▼
Continue   Unknown
```

Candidates outside the threshold are classified as Unknown.

---

## 22.10 Stage 7 — Ambiguity Detection

After threshold validation, the engine determines whether the recognition result is statistically unambiguous.

Decision Criteria:

- Difference between best and second-best distances
- Configured ambiguity margin

Decision:

```
Ambiguous?

        │
   ┌────┴────┐
   │         │
 No        Yes
   │         │
   ▼         ▼
Continue  Unknown
```

Only statistically distinct candidates proceed.

---

## 22.11 Stage 8 — Cooldown Validation

The engine verifies that command execution is currently permitted.

Decision:

```
Cooldown Active?

        │
   ┌────┴────┐
   │         │
 No        Yes
   │         │
   ▼         ▼
Execute   Ignore
```

Candidates detected during Cooldown are ignored rather than rejected.

This distinction simplifies diagnostics.

---

## 22.12 Stage 9 — Command Execution

If all previous stages succeed:

```
Recognition Accepted

↓

Execute Associated Action

↓

Log Recognition

↓

Enter Cooldown

↓

Listening
```

Execution shall occur exactly once.

Duplicate execution is prohibited.

---

## 22.13 Complete Decision Tree

```
Audio Event
     │
     ▼
Candidate Detected?
     │
 ┌───┴───┐
 │       │
No      Yes
 │       │
 ▼       ▼
End   Candidate Valid?
             │
         ┌───┴───┐
         │       │
        No      Yes
         │       │
         ▼       ▼
       Reject  Feature Extraction
                    │
                    ▼
          Feature Vector Valid?
               │
          ┌────┴────┐
          │         │
         No        Yes
          │         │
          ▼         ▼
       Reject   Classification
                     │
                     ▼
          Distance Within Threshold?
               │
          ┌────┴────┐
          │         │
         No        Yes
          │         │
          ▼         ▼
      Unknown  Ambiguous?
                   │
             ┌─────┴─────┐
             │           │
            Yes         No
             │           │
             ▼           ▼
        Unknown    Cooldown?
                       │
                 ┌─────┴─────┐
                 │           │
                Yes         No
                 │           │
                 ▼           ▼
             Ignore     Execute
```

This represents the canonical runtime decision process.

---

## 22.14 Early Exit Strategy

The decision tree intentionally employs an early-exit strategy.

Once a rejection condition is encountered, processing terminates immediately.

Examples:

- Invalid waveform
- Clipping detected
- Invalid Feature Vector
- Threshold failure
- Cooldown active

No further computation is performed.

This minimizes CPU usage and reduces recognition latency.

---

## 22.15 Decision Priorities

Decision stages are ordered from least computationally expensive to most computationally expensive.

Priority:

1. Candidate Detection
2. Signal Validation
3. Feature Extraction
4. Feature Validation
5. Statistical Classification
6. Threshold Validation
7. Ambiguity Detection
8. Cooldown Validation
9. Command Execution

This ordering ensures that expensive statistical computations are performed only for high-quality candidates.

---

## 22.16 Determinism

The Runtime Decision Tree guarantees:

- One unique execution path per candidate
- Explicit decision criteria
- No hidden state transitions
- No probabilistic branching
- No adaptive thresholds
- No runtime learning

Every candidate either:

- Executes one command,
- Is classified as Unknown, or
- Is rejected.

No intermediate outcomes are permitted.

---

## 22.17 Failure Handling

Failures at any decision stage shall:

- Terminate processing of the current candidate
- Log the failure reason (if diagnostics are enabled)
- Release temporary resources
- Return the engine to the Listening state

Recognition failures shall not affect subsequent candidates.

---

## 22.18 Summary

The Runtime Decision Tree formalizes the complete logical flow of runtime recognition.

By structuring recognition as a sequence of deterministic decisions with well-defined acceptance and rejection criteria, Tapper achieves predictable behavior, low latency, and robust handling of invalid acoustic events.

Together with the Runtime State Machine, this decision tree completely specifies the operational behavior of the recognition engine.

The following section presents the complete runtime pseudocode corresponding to the algorithms and decision processes defined throughout this specification.

# 23. Runtime Pseudocode

## 23.1 Purpose

This section presents the complete reference pseudocode for the Tapper Recognition Engine.

The pseudocode serves as the canonical implementation guide for the deterministic recognition algorithm described throughout this specification.

It is intended to:

- Illustrate the complete execution flow
- Clarify interactions between algorithmic components
- Serve as a reference for implementation
- Support testing and verification

The pseudocode is implementation-agnostic and does not prescribe a specific programming language.

---

## 23.2 High-Level Runtime Loop

The recognition engine operates continuously while recognition is enabled.

```text
Initialize Audio Engine

Load Calibration Profile

Initialize DSP Pipeline

Initialize Runtime State

while RecognitionEnabled

    Acquire Audio Samples

    Update Circular Buffer

    Detect Candidate

    if CandidateDetected

        Process Candidate

end while
```

This loop represents the highest level of the recognition engine.

---

## 23.3 Candidate Processing

Every candidate tap follows the same deterministic processing pipeline.

```text
function ProcessCandidate()

    if not ValidateCandidate()

        return Rejected

    FeatureVector = ExtractFeatures()

    if not ValidateFeatureVector(FeatureVector)

        return Rejected

    Result = Classify(FeatureVector)

    if not Result.Accepted

        return Unknown

    if CooldownActive()

        return Ignored

    ExecuteCommand(Result.Zone)

    StartCooldown()

    LogRecognition(Result)

end function
```

Each stage executes exactly once.

---

## 23.4 Candidate Detection

```text
function DetectCandidate()

    Peak = FindPeak()

    if Peak == NONE

        return False

    if PeakEnergy < DetectionThreshold

        return False

    return True

end function
```

Only transient acoustic events proceed further.

Detection is the only decision taken on the poll-aligned frame, and it uses only
the frame's peak magnitude, which is alignment-invariant (ADR-017 §2). Every
quality judgement is deferred until the event has been extracted.

### 23.4.1 Event Localisation and Extraction (ADR-017)

A detected frame identifies that something happened, not where. Before any
measurement the event shall be localised in the continuous sample stream and
extracted at an absolute position:

1. **Peak.** The event peak is the sample of largest magnitude in the filtered
   stream from the detected frame's peak up to the maximum attack interval
   after it. The frame may have captured only the beginning of the attack.
2. **Onset.** The onset is the earliest sample within the maximum onset
   look-back before the peak whose magnitude reaches the onset fraction of the
   peak (the same 10% fraction used by Attack Time, §14.11).
3. **Event window.** The event window begins a fixed pre-roll before the onset
   and spans the event-window length. It is read from the stream by absolute
   position once all of its samples have been captured; recognition waits for
   them rather than measuring a partial event.
4. **Filtering.** The band-pass filter runs over a warm-up interval preceding
   the event window, so its start-up transient never falls inside the window.

A detection whose frame peak lies inside an event window already extracted
belongs to that event and shall not start a second one.

| Parameter | Version 1 value | Status |
|---|---|---|
| Event-window length | 3360 samples (70 ms) | Set from hardware data, see below |
| Pre-roll | 48 samples (1 ms) | Provisional |
| Maximum onset look-back | 480 samples (10 ms) | Provisional |
| Maximum attack interval | 480 samples (10 ms) | Provisional |
| Filter warm-up | 480 samples (10 ms) | Provisional |

The event window is longer than the 1920-sample analysis frame, which remains
the unit of detection (§11). The spectrum of the event window is taken with a
4096-point FFT.

*Basis.* At CP-2 the 40 ms window was outlasted by 92.5% of natural taps, which
left no decay fit high-confidence. With the measured median time constant of
16.3 ms, the fit's −25 dB target is reached about 50 ms after onset; 70 ms
covers the median tap with margin. Detection latency is bounded by the window,
the maximum attack interval and one poll interval: 70 + 10 + 20 = 100 ms, within
the §24 target.

*Deviation from ADR-017 §3.* ADR-017 asks for the window to be derived per
calibration session. It is instead a constant set once from measured hardware
data, because a per-session window would change the measurement domain between
the calibration and the runtime that uses it, and would make profiles from
different sessions incomparable. Decays that outlast the window remain censored
(§14.13.5) rather than rejected.

---

## 23.5 Candidate Validation

```text
function ValidateCandidate(EventWindow)

    if SignalClipped

        return False

    if DecayEstimate == NONE

        return False                      // declined, §14.13.6

    if SignalDuration < MinimumDuration

        return False

    if SignalDuration > MaximumDuration and not Censored

        return False

    if RMS < MinimumEnergy

        return False

    if SignalToNoiseRatio < MinimumSNR

        return False

    return True

end function
```

Validation rejects poor-quality events before expensive processing occurs.

Every check is measured over the event window of §23.4.1, never over the frame
that triggered detection. RMS and SNR use the filtered, pre-normalization event
window. A declined decay estimate is reported as its own rejection reason,
distinct from a duration outside the limits (§14.13.6).

---

## 23.6 Feature Extraction

```text
function ExtractFeatures()

    ApplyBandpassFilter()

    ApplyHannWindow()

    FFT = ComputeFFT()

    FeatureVector =

    {

        PeakAmplitude,

        RMSEnergy,

        SpectralCentroid,

        SpectralBandwidth,

        SpectralRollOff,

        DominantFrequency,

        ZeroCrossingRate,

        AttackTime,

        DecayTime,

        SignalDuration

    }

    return FeatureVector

end function
```

The Feature Vector is immutable after construction.

---

## 23.7 Feature Validation

```text
function ValidateFeatureVector(Vector)

    for each Feature

        if NaN

            return False

        if Infinite

            return False

    end for

    return True

end function
```

Invalid numerical values terminate recognition immediately.

---

## 23.8 Classification

```text
function Classify(Vector)

    BestDistance = Infinity

    BestZone = Unknown

    for each ZoneProfile

        Distance =

        Mahalanobis(

            Vector,

            ZoneProfile

        )

        if Distance < BestDistance

            BestDistance = Distance

            BestZone = Zone

    end for

    return ValidateRecognition(

        BestZone,

        BestDistance

    )

end function
```

Every calibrated interaction zone is evaluated.

---

## 23.9 Threshold Validation

```text
function ValidateRecognition(

    Zone,

    Distance

)

    if Distance >

       Zone.Threshold

        return Rejected

    return Accepted

end function
```

Recognition requires threshold acceptance.

Selecting the nearest zone alone is insufficient.

---

## 23.10 Ambiguity Detection

```text
function DetectAmbiguity(

    BestDistance,

    SecondDistance

)

    Difference =

    SecondDistance

    -

    BestDistance

    if Difference

       <

       AmbiguityMargin

        return True

    return False

end function
```

Ambiguous recognitions become Unknown.

---

## 23.11 Confidence Calculation

```text
function ComputeConfidence(

    Distance,

    Threshold

)

    Confidence =

    100 *

    (

        1

        -

        Distance

          /

        Threshold

    )

    Clamp

    0

    100

    return Confidence

end function
```

Confidence is intended solely for diagnostics and user feedback.

---

## 23.12 Command Execution

```text
function ExecuteCommand(

    Zone

)

    Action =

    Zone.Action

    Execute(Action)

end function
```

Exactly one action is executed for each accepted recognition.

---

## 23.13 Cooldown

```text
function StartCooldown()

    CooldownActive = True

    Wait(

        CooldownDuration

    )

    CooldownActive = False

end function
```

Cooldown prevents duplicate recognition of a single physical tap.

---

## 23.14 Error Handling

```text
try

    ProcessCandidate()

catch Error

    Log(Error)

    ReturnToListening()

end try
```

Runtime failures affect only the current candidate.

The recognition engine continues operating whenever possible.

---

## 23.15 Complete Runtime Algorithm

```text
Initialize()

↓

Load Calibration

↓

Start Audio Stream

↓

Listening

↓

Candidate Detected?

↓

No

↓

Listening

↓

Yes

↓

Validate Candidate

↓

Reject?

↓

Yes

↓

Listening

↓

No

↓

Extract Features

↓

Validate Features

↓

Reject?

↓

Yes

↓

Listening

↓

No

↓

Classification

↓

Threshold Check

↓

Reject?

↓

Yes

↓

Unknown

↓

Listening

↓

No

↓

Ambiguity Check

↓

Ambiguous?

↓

Yes

↓

Unknown

↓

Listening

↓

No

↓

Cooldown?

↓

Yes

↓

Ignore

↓

Listening

↓

No

↓

Execute Command

↓

Cooldown

↓

Listening
```

This flow represents the canonical runtime algorithm and shall be preserved across all implementations.

---

## 23.16 Complexity Analysis

The runtime algorithm executes a fixed sequence of operations for every candidate.

For a constant number of interaction zones (**4**) and a fixed Feature Vector dimension (**10**):

- Candidate Validation: **O(1)**
- Feature Extraction: **O(N log N)** (FFT)
- Classification: **O(Z × d²)** where:
  - **Z** = Number of Zones
  - **d** = Feature Dimension

For Version 1:

```
Z = 4

d = 10
```

Since both values are constant, runtime classification executes in effectively constant time.

---

## 23.17 Deterministic Guarantees

The runtime algorithm guarantees:

- Constant execution path
- Fixed computational complexity
- Constant memory usage
- No adaptive learning
- No random number generation
- No cloud communication
- No dependency on previous recognitions

Given identical audio input and calibration data, the engine shall always produce the same recognition result.

---

## 23.18 Summary

This section provides the canonical reference pseudocode for the Tapper Recognition Engine.

It integrates the DSP pipeline, feature extraction, statistical classification, validation, ambiguity detection, cooldown management, and command execution into a single deterministic runtime workflow.

Together with the preceding mathematical and architectural specifications, this pseudocode forms a complete blueprint for implementing the Tapper recognition engine in any supported programming language while preserving identical runtime behavior.

# 24. Performance Targets

## 24.1 Purpose

The purpose of this section is to define the quantitative performance requirements for the Tapper Recognition Engine.

These targets establish measurable engineering objectives that guide implementation, optimization, testing, and future regression analysis.

All performance metrics defined in this section are normative unless explicitly stated otherwise.

Implementations should strive to meet or exceed these targets under typical operating conditions.

---

## 24.2 Design Philosophy

The Tapper Recognition Engine is intended to operate as a real-time interactive system.

Recognition latency must be sufficiently low that users perceive command execution as instantaneous.

Performance improvements shall never compromise:

- Determinism
- Recognition accuracy
- Numerical stability
- Statistical correctness

Correctness always takes precedence over raw execution speed.

---

## 24.3 Runtime Performance Goals

The recognition pipeline shall satisfy the following runtime objectives.

| Metric | Target |
|---------|-------:|
| End-to-End Recognition Latency | < 50 ms |
| Candidate Validation | < 2 ms |
| Feature Extraction | < 10 ms |
| Statistical Classification | < 5 ms |
| Decision Validation | < 2 ms |
| Command Dispatch Overhead | < 5 ms |

Remaining time budget is reserved for:

- Audio buffering
- Operating system scheduling
- Runtime overhead

---

## 24.4 Recognition Latency

Recognition latency is defined as:

> The elapsed time between the arrival of a valid tap at the microphone and the initiation of the associated command.

Latency includes:

- Audio acquisition
- Candidate detection
- DSP
- Feature extraction
- Classification
- Validation
- Command dispatch

Latency excludes:

- Application-specific command execution time
- Operating system scheduling delays outside the recognition engine

---

## 24.5 Recognition Accuracy

Under representative calibration conditions, Tapper shall achieve:

| Metric | Target |
|---------|--------|
| Overall Recognition Accuracy | ≥ 95% |
| Per-Zone Accuracy | ≥ 95% |
| Calibration Success Rate | ≥ 98% |

Accuracy measurements shall be based on statistically significant testing across multiple users and supported devices.

---

## 24.6 False Positive Rate

False positives occur when a non-tap event is incorrectly classified as a valid interaction.

Target:

```
False Positive Rate

< 1%
```

Examples include:

- Keyboard typing
- Speech
- Desk vibration
- Laptop movement

Minimizing false positives is considered a higher priority than maximizing sensitivity.

---

## 24.7 False Negative Rate

False negatives occur when a legitimate intentional tap is rejected.

Target:

```
False Negative Rate

< 5%
```

False negatives may result from:

- Extremely weak taps
- Poor calibration
- Excessive environmental noise

A modest false-negative rate is acceptable if it significantly reduces false positives.

---

## 24.8 CPU Utilization

The recognition engine shall maintain minimal CPU usage during continuous operation.

Target:

| Scenario | CPU Usage |
|----------|----------:|
| Idle Listening | < 2% |
| Normal Recognition | < 5% |
| Calibration | < 10% |

These values assume contemporary Apple Silicon hardware.

---

## 24.9 Memory Utilization

The recognition engine is designed for constant memory usage.

Recommended targets:

| Component | Target |
|----------|--------:|
| DSP Buffers | < 20 MB |
| Calibration Profiles | < 5 MB |
| Runtime Objects | < 10 MB |
| Total Memory | < 100 MB |

Memory usage shall remain effectively constant regardless of runtime duration.

---

## 24.10 Storage Requirements

Persistent storage requirements are intentionally minimal.

Typical calibration profile:

```
Mean Vectors

+

Covariance Matrices

+

Thresholds

+

Metadata
```

Expected profile size:

```
< 100 KB
```

Raw audio recordings shall not be stored unless explicitly enabled for diagnostics.

---

## 24.11 Startup Performance

Recognition should become operational shortly after application launch.

Target startup sequence:

| Stage | Target |
|--------|-------:|
| Load Calibration Profile | < 100 ms |
| Initialize DSP Pipeline | < 50 ms |
| Start Audio Engine | < 100 ms |
| Total Startup Time | < 500 ms |

---

## 24.12 Calibration Performance

Calibration should complete within a reasonable duration without sacrificing statistical quality.

Recommended targets:

| Metric | Target |
|--------|-------:|
| Environment Verification | < 3 s |
| Single Tap Processing | < 50 ms |
| Per-Zone Calibration | < 30 s |
| Complete Calibration | < 2 min |

Actual duration depends primarily on user interaction speed.

---

## 24.13 Scalability

The algorithm shall scale efficiently with the number of calibrated interaction zones.

The computational cost of classification grows linearly with the number of zones.

```
Runtime Complexity

O(Z)
```

where:

```
Z

=

Number of Zones
```

Version 1 defines:

```
Z = 4
```

Future versions supporting additional interaction zones should remain well within real-time performance limits.

---

## 24.14 Numerical Stability

All statistical computations shall use:

```
64-bit Floating Point Precision
```

Acceptable numerical error:

```
< 10⁻⁹
```

Matrix inversion and covariance computations shall remain stable across repeated calibration sessions.

---

## 24.15 Energy Efficiency

Tapper is intended to operate continuously in the background.

The recognition engine shall therefore minimize:

- CPU wakeups
- Memory allocations
- Disk writes
- Background activity

No unnecessary polling shall occur outside the continuous audio acquisition process.

---

## 24.16 Reliability Targets

The recognition engine shall satisfy the following operational reliability goals.

| Metric | Target |
|---------|--------|
| Runtime Crash Rate | 0 |
| Memory Leaks | None |
| Deterministic Execution | 100% |
| Profile Corruption Tolerance | Recoverable |

Unexpected runtime failures shall affect only the current recognition event.

The engine shall recover automatically whenever possible.

---

## 24.17 Benchmarking

Performance testing shall include:

- Quiet environments
- Moderate office noise
- Continuous typing nearby
- Music playback
- Multiple supported MacBook models
- Extended runtime sessions

Benchmarking shall evaluate both latency and recognition accuracy.

---

## 24.18 Regression Testing

Every algorithm revision shall be evaluated against previous versions.

Regression testing shall verify:

- Recognition accuracy
- Runtime latency
- CPU utilization
- Memory consumption
- Calibration quality
- Numerical consistency

Performance regressions shall be investigated before release.

---

## 24.19 Summary

The performance targets defined in this section establish measurable engineering goals for the Tapper Recognition Engine.

By maintaining low latency, high recognition accuracy, predictable resource consumption, and deterministic execution, Tapper provides a responsive and reliable user experience while remaining suitable for continuous background operation on supported Apple hardware.

These targets serve as the benchmark against which future algorithm optimizations and architectural changes shall be evaluated.

# 25. Computational Complexity

## 25.1 Purpose

This section analyzes the computational complexity of the Tapper Recognition Engine.

Understanding the computational characteristics of each subsystem is essential for:

- Performance optimization
- Capacity planning
- Hardware compatibility
- Battery efficiency
- Real-time guarantees

Unlike many machine learning systems whose computational cost grows significantly with model size, Tapper is designed as a deterministic algorithm with predictable and bounded execution time.

---

## 25.2 Design Goals

The recognition engine shall satisfy the following computational objectives:

- Constant memory usage
- Predictable execution time
- Linear scalability with interaction zones
- Minimal CPU utilization
- Real-time responsiveness
- Efficient background operation

No algorithm shall exhibit unbounded computational growth during continuous runtime.

---

## 25.3 Complexity Notation

The following notation is used throughout this section.

| Symbol | Description |
|---------|-------------|
| **N** | Number of audio samples in an analysis window |
| **F** | Number of extracted features |
| **Z** | Number of calibrated interaction zones |
| **C** | Number of calibration samples per zone |

For Version 1:

```
N = 2048

F = 10

Z = 4

C = 20
```

Since these values are fixed, practical runtime complexity is effectively constant.

---

## 25.4 Audio Acquisition

Audio acquisition consists of continuously appending incoming samples to a circular buffer.

Each incoming sample requires:

- Buffer write
- Pointer increment
- Boundary check

Complexity:

```
Time

O(1)

Memory

O(N)
```

Circular buffers eliminate dynamic memory allocation during runtime.

---

## 25.5 Candidate Detection

Candidate detection scans the current analysis window for transient events.

Operations include:

- Peak search
- Energy calculation
- Threshold comparison

Complexity:

```
Time

O(N)

Memory

O(1)
```

As the analysis window size remains fixed, execution time is constant in practice.

---

## 25.6 Digital Filtering

The Butterworth IIR filter processes each audio sample once.

Each sample requires a fixed number of arithmetic operations.

Complexity:

```
Time

O(N)

Memory

O(1)
```

The filter order remains constant.

---

## 25.7 Windowing

Applying the Hann window requires one multiplication per sample.

Complexity:

```
Time

O(N)

Memory

O(1)
```

The window coefficients are precomputed during initialization.

---

## 25.8 Fast Fourier Transform

FFT computation represents the most computationally intensive DSP operation.

The radix-2 FFT executes in:

```
Time

O(N log N)

Memory

O(N)
```

For:

```
N = 2048
```

The computational cost remains comfortably within real-time constraints on supported Apple Silicon hardware.

---

## 25.9 Feature Extraction

Feature extraction computes a fixed number of measurements from both the time and frequency domains.

Each feature requires a bounded number of operations.

Complexity:

```
Time

O(N)

Memory

O(F)
```

Since:

```
F = 10
```

Feature storage remains constant.

---

## 25.10 Feature Validation

Feature validation verifies numerical correctness.

Operations include:

- NaN detection
- Infinity detection
- Range validation

Complexity:

```
Time

O(F)

Memory

O(1)
```

---

## 25.11 Statistical Classification

Each Feature Vector is compared against every calibrated interaction zone.

For each zone:

- Mean subtraction
- Matrix multiplication
- Mahalanobis distance computation

Complexity:

```
Time

O(Z × F²)

Memory

O(F²)
```

Since:

```
Z = 4

F = 10
```

Classification executes in effectively constant time.

---

## 25.12 Matrix Operations

Mahalanobis Distance requires multiplication by the inverse covariance matrix.

The inverse covariance matrix is computed during calibration and stored persistently.

Runtime classification therefore performs only matrix-vector multiplication.

No matrix inversion occurs during recognition.

Complexity:

```
Time

O(F²)

Memory

O(F²)
```

This design significantly reduces runtime computational cost.

---

## 25.13 Candidate Ranking

Distances from all interaction zones are compared.

Version 1 uses only four zones.

Complexity:

```
Time

O(Z)

Memory

O(1)
```

Sorting is unnecessary.

A simple minimum-distance search is sufficient.

---

## 25.14 Threshold Validation

Threshold validation performs one comparison.

Complexity:

```
Time

O(1)

Memory

O(1)
```

---

## 25.15 Cooldown Validation

Cooldown validation checks the current system timestamp.

Complexity:

```
Time

O(1)

Memory

O(1)
```

---

## 25.16 Command Dispatch

Action dispatch consists of:

- Action lookup
- Command invocation
- Diagnostics logging

Complexity:

```
Time

O(1)

Memory

O(1)
```

Command execution latency is considered external to the recognition algorithm.

---

## 25.17 Calibration Complexity

Calibration performs statistical computations on the collected Feature Vectors.

Operations include:

- Mean computation
- Covariance computation
- Threshold estimation

Complexity:

Mean Vector

```
O(C × F)
```

Covariance Matrix

```
O(C × F²)
```

For Version 1:

```
C = 20

F = 10
```

Calibration completes comfortably within interactive time constraints.

---

## 25.18 Overall Runtime Complexity

Combining all recognition stages:

| Stage | Complexity |
|---------|-----------|
| Candidate Detection | O(N) |
| Filtering | O(N) |
| Windowing | O(N) |
| FFT | O(N log N) |
| Feature Extraction | O(N) |
| Classification | O(Z × F²) |
| Validation | O(1) |
| Command Dispatch | O(1) |

The FFT dominates runtime complexity.

---

## 25.19 Memory Complexity

The recognition engine maintains a fixed collection of runtime objects.

Memory consumers include:

- Circular audio buffer
- FFT workspace
- Feature Vector
- Calibration profiles
- Temporary matrices

Overall memory complexity:

```
O(N + Z × F²)
```

Since both **Z** and **F** are fixed constants, memory usage remains effectively constant throughout execution.

No runtime memory growth is permitted.

---

## 25.20 Real-Time Suitability

The bounded computational complexity of every subsystem ensures that the recognition engine satisfies real-time execution requirements.

Key properties include:

- Constant-size data structures
- No recursive algorithms
- No dynamic model updates
- No unbounded searches
- No runtime matrix inversion
- Fixed-dimensional statistical computations

These characteristics make Tapper well suited for continuous background execution with minimal impact on overall system performance.

---

## 25.21 Scalability

Future versions may introduce:

- Additional interaction zones
- Additional acoustic features
- Gesture recognition
- Multi-tap recognition

The computational impact scales predictably.

Increasing the number of zones affects classification linearly.

Increasing the number of features affects covariance and distance computations quadratically.

These relationships should guide future architectural decisions.

---

## 25.22 Summary

The Tapper Recognition Engine exhibits predictable and bounded computational complexity across all stages of operation.

Its runtime is dominated by the FFT, while statistical classification remains lightweight due to the fixed number of features and interaction zones.

The use of precomputed calibration models, fixed-size data structures, and deterministic algorithms ensures that recognition remains suitable for continuous real-time execution on supported hardware with low CPU utilization, constant memory usage, and minimal energy consumption.

# 26. Failure Handling

## 26.1 Purpose

This section defines the procedures for detecting, reporting, and recovering from failures encountered by the Tapper Recognition Engine.

Despite operating in a controlled environment, runtime failures may occur due to hardware faults, operating system behavior, invalid calibration data, or unexpected input conditions.

The recognition engine shall detect such failures, recover whenever possible, and prevent undefined behavior.

Failure handling shall never compromise the deterministic operation of the recognition pipeline.

---

## 26.2 Design Goals

The failure handling subsystem shall satisfy the following objectives:

- Detect failures immediately
- Isolate failures to the current recognition event
- Prevent propagation of invalid state
- Recover automatically whenever possible
- Preserve application stability
- Generate useful diagnostic information

Under no circumstances shall an internal failure result in undefined recognition behavior.

---

## 26.3 Failure Classification

Failures are categorized into three severity levels.

### Recoverable

Failures that affect only the current recognition event.

Examples:

- Invalid Feature Vector
- Candidate validation failure
- Threshold rejection
- Cooldown conflict

Recognition continues immediately after the event.

---

### Session-Level

Failures requiring partial subsystem reinitialization.

Examples:

- Audio interruption
- Temporary microphone unavailability
- Audio buffer corruption
- DSP initialization failure

Recognition pauses until recovery completes.

---

### Fatal

Failures preventing safe recognition.

Examples:

- Missing calibration profile
- Corrupted calibration data
- Matrix inversion failure
- Unsupported hardware
- Critical internal consistency error

Recognition remains disabled until corrective action is taken.

---

## 26.4 Failure Detection

Every subsystem shall validate its inputs before processing.

Subsystems include:

- Audio Engine
- Candidate Detection
- DSP Pipeline
- Feature Extraction
- Classification Engine
- Command Dispatcher

If validation fails, processing terminates immediately for the current event.

---

## 26.5 Audio Engine Failures

Possible failures include:

- Microphone disconnected
- Permission revoked
- Audio device unavailable
- Sample rate mismatch
- Stream interruption

Required behavior:

```
Stop Recognition

↓

Release Resources

↓

Attempt Reinitialization

↓

Listening
```

If recovery is unsuccessful, transition to the Error state.

---

## 26.6 DSP Failures

Failures occurring during signal processing include:

- Filter initialization failure
- FFT computation failure
- Window generation failure
- Numerical overflow

The current candidate shall be discarded.

The DSP pipeline shall be reinitialized before processing subsequent candidates.

---

## 26.7 Feature Extraction Failures

Feature extraction fails if:

- FFT results are invalid
- Required features cannot be computed
- Numerical instability is detected
- Invalid intermediate values occur

Result:

```
Reject Candidate

↓

Log Failure

↓

Listening
```

No statistical classification shall occur.

---

## 26.8 Feature Validation Failures

Feature validation rejects vectors containing:

- NaN values
- Infinite values
- Missing dimensions
- Physically impossible measurements

The Feature Vector shall be discarded immediately.

No attempt shall be made to repair invalid data.

---

## 26.9 Classification Failures

Classification failures include:

- Missing Zone Profile
- Invalid covariance matrix
- Matrix multiplication failure
- Distance computation failure

Required behavior:

```
Abort Classification

↓

Log Failure

↓

Listening
```

The candidate shall not execute any action.

---

## 26.10 Calibration Profile Failures

A calibration profile shall be considered invalid if:

- Required fields are missing
- Mean vector dimensions are incorrect
- Covariance matrix dimensions are incorrect
- Thresholds are absent
- Algorithm version mismatch occurs

Recognition shall not begin with an invalid profile.

Users shall be prompted to recalibrate.

---

## 26.11 Covariance Matrix Failures

Mahalanobis Distance requires a valid inverse covariance matrix.

Failure conditions include:

- Singular matrix
- Non-positive-definite matrix
- Numerical instability
- Failed inversion

The affected Zone Profile shall be marked invalid.

Runtime classification shall terminate immediately.

---

## 26.12 Storage Failures

Persistent storage failures may occur during:

- Calibration save
- Profile update
- Settings persistence

Requirements:

- Existing valid profiles shall never be overwritten until the new profile has been successfully written.
- Writes shall be atomic whenever supported by the underlying storage system.
- Partial writes shall be discarded.

This prevents profile corruption.

---

## 26.13 Command Execution Failures

Command execution failures occur outside the statistical recognition engine.

Examples:

- Application unavailable
- Shortcut execution failure
- Permission denied
- Operating system rejection

Recognition shall still be considered successful.

The execution failure shall be logged independently.

Subsequent recognitions shall continue normally.

---

## 26.14 Memory Failures

If memory allocation fails:

- Abort the current recognition
- Release temporary resources
- Preserve calibration data
- Return to Listening if possible

Persistent memory exhaustion shall transition the engine to the Error state.

---

## 26.15 Unexpected Exceptions

Any unexpected internal exception shall be treated as a recoverable failure unless system integrity cannot be guaranteed.

General recovery sequence:

```
Exception

↓

Log Error

↓

Release Temporary Resources

↓

Reset Runtime State

↓

Listening
```

Recognition shall resume automatically whenever safe.

---

## 26.16 Diagnostics Logging

Every failure shall generate a structured diagnostic record.

Minimum fields:

```
Timestamp

Subsystem

Failure Type

Severity

Description

Recovery Action
```

Example:

```
14:52:11.324

Classification

Matrix Inversion Failure

Fatal

Recognition Disabled
```

Structured diagnostics simplify troubleshooting and post-mortem analysis.

---

## 26.17 User Feedback

Failures visible to the user shall be communicated clearly.

Examples:

| Failure | User Message |
|---------|--------------|
| Missing Calibration | Calibration required before recognition can begin. |
| Microphone Permission | Microphone access is required. |
| Audio Device Failure | Audio input unavailable. |
| Profile Corruption | Calibration profile is invalid. Please recalibrate. |

Internal implementation details shall not be exposed in user-facing messages.

---

## 26.18 Recovery Strategy

Whenever possible, failures shall be recovered automatically.

Priority:

1. Retry operation
2. Reinitialize subsystem
3. Reset recognition state
4. Disable recognition
5. Request user intervention

Automatic recovery should always be preferred over requiring manual intervention.

---

## 26.19 Failure Isolation

Failures shall remain isolated to the smallest possible scope.

Examples:

- A rejected candidate shall not affect future recognitions.
- A failed command execution shall not invalidate the recognition engine.
- A temporary microphone interruption shall not corrupt calibration data.

Subsystem independence improves reliability and simplifies testing.

---

## 26.20 Deterministic Failure Behavior

Failure handling shall itself remain deterministic.

Given identical failure conditions, the engine shall always:

- Detect the same failure
- Produce the same diagnostic information
- Perform the same recovery sequence
- Return to the same runtime state

No randomized recovery behavior is permitted.

---

## 26.21 Summary

The failure handling architecture ensures that the Tapper Recognition Engine remains robust under both expected and unexpected operating conditions.

By validating every stage of the recognition pipeline, isolating failures to the smallest practical scope, and favoring automatic recovery, the engine maintains stability without compromising deterministic recognition behavior.

The following section defines the configurable parameters that may be tuned without altering the underlying recognition algorithm.

# 27. Tunable Parameters

## 27.1 Purpose

This section defines the configurable parameters of the Tapper Recognition Engine.

Tunable parameters allow implementations to optimize recognition performance for supported hardware and operating environments without modifying the core recognition algorithm.

These parameters influence operational characteristics such as sensitivity, latency, and robustness, while preserving the deterministic statistical model described in this specification.

Changing a tunable parameter shall **never** alter the mathematical foundations of the recognition engine.

---

## 27.2 Design Principles

All configurable parameters shall satisfy the following principles:

- Deterministic behavior
- Explicit documentation
- Clearly defined valid ranges
- Safe default values
- Backward compatibility where possible

Parameter changes shall take effect only after successful validation.

Invalid parameter values shall be rejected.

---

## 27.3 Parameter Categories

Version 1 groups parameters into the following categories:

- Audio Acquisition
- Signal Processing
- Candidate Detection
- Feature Extraction
- Statistical Classification
- Runtime Control
- Diagnostics

Each category is described below.

---

# 27.4 Audio Acquisition Parameters

These parameters define how raw audio is captured.

| Parameter | Default | Unit |
|-----------|---------|------|
| Sample Rate | 48,000 | Hz |
| Channels | 1 | Mono |
| Sample Format | Float32 | — |
| Buffer Size | 2048 | Samples |

These parameters should remain fixed for Version 1.

Changing the sample rate may invalidate calibration profiles.

---

# 27.5 DSP Parameters

Signal processing parameters determine how raw audio is prepared for feature extraction.

| Parameter | Default |
|-----------|---------|
| High-Pass Cutoff | 300 Hz |
| Low-Pass Cutoff | 6000 Hz |
| Filter Type | Butterworth |
| Filter Order | 4 |
| Window Function | Hann |
| FFT Size | 2048 |

These parameters should not be modified without recalibration.

---

# 27.6 Candidate Detection Parameters

Candidate detection determines when an acoustic event should enter the recognition pipeline.

| Parameter | Description |
|-----------|-------------|
| Detection Threshold | Minimum peak energy |
| Minimum RMS Energy | Reject weak events |
| Minimum SNR | Reject noisy events |
| Peak Search Window | Candidate search duration |
| Maximum Candidate Duration | Reject sustained sounds |

Increasing sensitivity increases the likelihood of false positives.

Reducing sensitivity increases the likelihood of false negatives.

---

# 27.7 Feature Extraction Parameters

The following parameters influence feature computation.

| Parameter | Description |
|-----------|-------------|
| FFT Resolution | Frequency precision |
| Roll-off Percentage | Spectral Roll-off computation |
| Attack Threshold | Attack Time measurement |
| Decay Threshold | Decay Time measurement |

These parameters shall remain constant for a given algorithm version.

---

# 27.8 Statistical Classification Parameters

The statistical classifier exposes a limited number of configurable values.

| Parameter | Description |
|-----------|-------------|
| Threshold Multiplier | Controls acceptance threshold |
| Ambiguity Margin | Minimum separation between candidates |
| Confidence Scaling | Diagnostic confidence calculation |

These parameters influence recognition sensitivity but do not alter the underlying statistical model.

---

# 27.9 Runtime Parameters

Runtime behavior is governed by several timing-related parameters.

| Parameter | Default |
|-----------|---------|
| Cooldown Duration | 100 ms |
| Diagnostics Buffer Size | 100 Events |
| Recognition Timeout | 50 ms |

Cooldown duration should balance responsiveness with duplicate suppression.

---

# 27.10 Calibration Parameters

Calibration exposes a small number of configurable values.

| Parameter | Default |
|-----------|---------|
| Samples per Zone | 20 |
| Noise Measurement Duration | 2 s |
| Maximum Rejected Samples | 10 |
| Minimum Calibration Quality | 70% |

Reducing the number of calibration samples decreases calibration time but may reduce statistical reliability.

---

# 27.11 Diagnostics Parameters

Diagnostics settings affect only logging and user feedback.

| Parameter | Description |
|-----------|-------------|
| Diagnostics Enabled | Enable detailed logging |
| Quality History Length | Number of stored quality scores |
| Log Verbosity | Logging detail level |
| Export Diagnostics | Allow diagnostic export |

Diagnostics parameters shall never influence recognition decisions.

---

# 27.12 Parameter Validation

Every configurable parameter shall be validated before being applied.

Validation includes:

- Correct data type
- Valid numerical range
- Internal consistency
- Compatibility with the current algorithm version

Invalid parameters shall be rejected.

The engine shall continue operating with the previous valid configuration.

---

# 27.13 Calibration Dependency

Certain parameters directly influence the statistical properties of the Feature Vector.

Examples include:

- Sample Rate
- FFT Size
- Filter Characteristics
- Window Function

Changing any of these parameters invalidates existing calibration profiles.

A full recalibration shall be required before recognition resumes.

---

# 27.14 Version Compatibility

Every calibration profile shall record the algorithm version and parameter set used during calibration.

At startup, the recognition engine shall verify compatibility between:

- Stored calibration profile
- Current algorithm version
- Current parameter configuration

If incompatibility is detected, recognition shall be disabled until recalibration is completed.

---

# 27.15 User Configuration

Only a subset of parameters should be exposed through the user interface.

Recommended user-adjustable settings include:

- Cooldown Duration
- Diagnostics Mode
- Calibration Restart
- Recognition Enable/Disable

Advanced DSP and statistical parameters should remain inaccessible to prevent accidental degradation of recognition performance.

---

# 27.16 Developer Configuration

Implementation-specific builds may expose additional configuration options for development and testing.

Examples include:

- Threshold multiplier adjustment
- Ambiguity margin tuning
- Filter coefficient overrides
- Feature logging
- Statistical visualization

Developer settings shall not be enabled in production releases by default.

---

# 27.17 Default Configuration

The default parameter set defined in this specification represents the reference implementation.

Any implementation claiming compliance with Version 1 shall use these defaults unless explicitly documented otherwise.

Alternative configurations shall be clearly versioned to ensure reproducibility and compatibility.

---

# 27.18 Parameter Persistence

User-configurable parameters shall be stored independently of calibration profiles.

Updating runtime settings such as diagnostics mode or cooldown duration shall not modify calibration data.

Parameters affecting DSP or feature extraction shall require recalibration before taking effect.

---

# 27.19 Summary

The tunable parameters defined in this section provide controlled flexibility for adapting the Tapper Recognition Engine to different hardware configurations and user preferences while preserving deterministic behavior.

By clearly separating runtime settings, calibration-dependent parameters, and developer-only configuration options, the engine maintains reproducibility, compatibility, and statistical integrity across implementations.

The following and final section outlines future enhancements that may extend the recognition engine while remaining consistent with the architectural principles established throughout this specification.

# 28. Future Enhancements

## 28.1 Purpose

This section identifies potential future enhancements to the Tapper Recognition Engine.

The features described herein are **informative rather than normative**. They are not part of the Version 1 specification and shall not be required for compliance.

Each proposed enhancement has been evaluated for compatibility with the core architectural principles established throughout this document:

- Deterministic recognition
- Real-time performance
- Low computational overhead
- Statistical interpretability
- Privacy-first design
- On-device processing

Future implementations should preserve these principles wherever practical.

---

## 28.2 Design Philosophy

The Version 1 recognition engine intentionally prioritizes:

- Simplicity
- Reliability
- Deterministic behavior
- Ease of implementation

Future versions should extend the system incrementally rather than replacing the underlying architecture.

Backward compatibility should be maintained whenever possible.

---

## 28.3 Additional Interaction Zones

Version 1 supports four interaction zones.

Future versions may support finer spatial resolution.

Possible layouts include:

```
6 Zones

┌────────────────────┐
│ TL   TC   TR       │
│                    │
│ BL   BC   BR       │
└────────────────────┘
```

or

```
3 × 3 Grid

┌───────────────┐
│ A  B  C       │
│ D  E  F       │
│ G  H  I       │
└───────────────┘
```

Increasing the number of zones improves interaction flexibility but requires more comprehensive calibration and increases classification complexity linearly.

---

## 28.4 Gesture Recognition

Version 1 recognizes only single taps.

Future versions may introduce temporal gesture recognition, including:

- Double Tap
- Triple Tap
- Long Tap
- Rapid Burst
- Sequential Zone Taps

Example:

```
Top Left

↓

Top Right

↓

Bottom Right
```

Such gestures would require an additional temporal analysis layer above the existing Classification Engine.

---

## 28.5 Multi-Touch Interaction

Current recognition assumes a single acoustic source.

Future work may investigate simultaneous taps involving:

- Two fingers
- Multiple users
- Chord-style gestures

These scenarios introduce overlapping resonance patterns and require more advanced signal separation techniques.

---

## 28.6 Adaptive Threshold Optimization

Version 1 derives thresholds exclusively during calibration.

Future versions may explore deterministic adaptive threshold refinement based on long-term recognition statistics.

Potential adjustments include:

- Environmental noise adaptation
- Seasonal hardware variation
- Device aging compensation

Adaptive mechanisms shall preserve deterministic execution and shall never modify calibration data without explicit user consent.

---

## 28.7 Enhanced Calibration

Calibration may be expanded with additional quality assurance features.

Possible enhancements include:

- Automatic sample quality scoring
- Real-time coaching
- Dynamic sample count adjustment
- Zone consistency analysis
- Calibration replay

These improvements aim to reduce calibration errors while improving the user experience.

---

## 28.8 Environmental Awareness

Future versions may classify ambient acoustic environments.

Examples include:

- Quiet room
- Office
- Café
- Classroom
- Public transport

Environmental classification could allow runtime recommendations such as:

```
Ambient Noise High

Recommendation:

Increase Tap Force
```

Recognition thresholds should remain deterministic and user-controlled.

---

## 28.9 Hardware Optimization

Future implementations may optimize recognition for specific Apple hardware generations.

Examples include:

- MacBook Air
- MacBook Pro
- Different chassis sizes
- Future Apple Silicon devices

Hardware-specific calibration profiles may improve recognition consistency while preserving algorithmic compatibility.

---

## 28.10 Feature Expansion

The current Feature Vector contains ten acoustic features.

Additional features may include:

- Spectral Flux
- Spectral Flatness
- Spectral Crest
- Harmonic Ratio
- Resonance Persistence
- Wavelet Coefficients
- Cepstral Features

New features should demonstrate measurable improvements before inclusion.

Feature additions require algorithm versioning and recalibration.

---

## 28.11 Advanced Statistical Models

The Version 1 classifier employs Mahalanobis Distance.

Future deterministic alternatives may include:

- Gaussian Mixture Models
- Bayesian Classification
- Hidden Markov Models (for temporal gestures)
- Linear Discriminant Analysis
- Quadratic Discriminant Analysis

Any replacement shall provide demonstrable improvements while maintaining deterministic behavior and interpretability.

---

## 28.12 Machine Learning Research

Although Version 1 explicitly excludes machine learning, future research may investigate hybrid recognition approaches.

Potential applications include:

- Automatic feature selection
- Calibration assistance
- Noise classification
- Gesture prediction

Any machine learning components should remain optional and must not replace the deterministic recognition pipeline without a major version revision.

---

## 28.13 Cross-Device Synchronization

Future releases may support synchronizing user preferences across multiple devices.

Synchronization may include:

- Runtime settings
- Command mappings
- User interface preferences

Calibration profiles should remain device-specific due to differences in chassis acoustics and microphone characteristics.

---

## 28.14 Accessibility Enhancements

Future improvements may include accessibility-focused features such as:

- Alternative calibration workflows
- Visual and auditory guidance
- Adjustable interaction sensitivity
- Voice-assisted setup
- High-contrast diagnostic interfaces

Accessibility improvements should integrate seamlessly with the existing recognition architecture.

---

## 28.15 Diagnostics and Analytics

Diagnostics may be expanded with additional tools, including:

- Live waveform visualization
- Spectrogram display
- Feature trend analysis
- Calibration comparison
- Performance dashboards
- Recognition heat maps

These tools would primarily support development, testing, and advanced users.

---

## 28.16 Security and Privacy

Future versions should continue to prioritize user privacy.

Potential enhancements include:

- Encrypted calibration profiles
- Secure diagnostics export
- Integrity verification
- Profile signing
- Enhanced sandboxing

All recognition should continue to occur entirely on-device.

No raw audio or acoustic data should be transmitted externally without explicit user authorization.

---

## 28.17 API and Integration

Future releases may expose a stable public API.

Potential capabilities include:

- Custom command providers
- Plugin architecture
- Automation integrations
- Scripting interfaces
- Third-party extensions

The recognition engine should remain independent of higher-level integrations.

---

## 28.18 Research Directions

Long-term research topics include:

- Acoustic localization across the entire chassis
- Finger identification through resonance patterns
- Continuous resonance mapping
- Device-independent statistical models
- Multi-device cooperative recognition
- Fusion with inertial or haptic sensors

These topics extend beyond the scope of Version 1 but may influence future architectural evolution.

---

## 28.19 Backward Compatibility

Future enhancements should preserve compatibility wherever practical.

Major algorithmic changes that affect:

- Feature extraction
- Statistical modeling
- Calibration profiles
- Recognition semantics

shall require a new algorithm version identifier and a full recalibration process.

This ensures reproducibility and prevents incompatibility between versions.

---

## 28.20 Summary

The Tapper Recognition Engine has been intentionally designed with extensibility as a core architectural principle.

The deterministic DSP pipeline, fixed Feature Vector representation, statistical classification framework, and modular runtime architecture provide a solid foundation upon which future capabilities can be built.

Version 1 establishes a reliable, interpretable, and efficient recognition engine focused on single-tap acoustic interaction. Future versions may expand spatial resolution, gesture recognition, diagnostics, accessibility, and hardware optimization while preserving the engineering principles defined throughout this specification.

---

# End of Document

This document constitutes the complete Version 1 engineering specification for the Tapper Recognition Algorithm.

It defines the digital signal processing pipeline, statistical recognition model, calibration methodology, runtime architecture, performance requirements, failure handling, and extensibility guidelines necessary to implement a deterministic, on-device acoustic tap recognition system.

Any implementation claiming compliance with this specification shall adhere to the normative requirements defined throughout this document.

# Appendix A – Constants and Default Values

## A.1 Purpose

This appendix consolidates all default constants and engineering parameters defined throughout this specification.

These values represent the **reference implementation** for Tapper Version 1.

Any implementation deviating from these defaults shall document the changes explicitly and, where applicable, require recalibration.

---

## A.2 Audio Acquisition

| Constant | Default | Unit | Notes |
|----------|---------|------|------|
| Sample Rate | 48,000 | Hz | Native processing rate |
| Channels | 1 | Mono | Single microphone channel |
| Sample Format | Float32 | — | IEEE-754 floating point |
| Buffer Type | Circular Buffer | — | Continuous streaming |
| Buffer Size | 2048 | Samples | DSP processing window |

---

## A.3 Digital Signal Processing

| Constant | Default | Unit |
|----------|---------|------|
| Filter Type | Butterworth | — |
| Filter Order | 4 | — |
| High-Pass Cutoff | 300 | Hz |
| Low-Pass Cutoff | 6000 | Hz |
| Window Function | Hann | — |
| FFT Size | 2048 | Samples |
| Window Duration | 40 | ms |
| Window Overlap | 50 | % |

---

## A.4 Feature Extraction

| Constant | Default |
|----------|---------|
| Feature Count | 10 |
| Feature Precision | Float64 |
| Frequency Resolution | ~23.44 Hz/bin |

Extracted Features:

1. Peak Amplitude
2. RMS Energy
3. Spectral Centroid
4. Spectral Bandwidth
5. Spectral Roll-off
6. Dominant Frequency
7. Zero Crossing Rate
8. Attack Time
9. Decay Time
10. Signal Duration

---

## A.5 Calibration

| Constant | Default | Unit |
|----------|---------|------|
| Zones | 4 | — |
| Samples per Zone | 20 | Taps |
| Total Samples | 80 | Taps |
| Noise Measurement | 2 | Seconds |
| Minimum Calibration Quality | 70 | % |

---

## A.6 Runtime Recognition

| Constant | Default | Unit |
|----------|---------|------|
| Recognition Latency Target | <50 | ms |
| Cooldown Duration | 100 | ms |
| Confidence Range | 0–100 | % |
| Ambiguity Detection | Enabled | — |
| Unknown Zone Support | Yes | — |

---

## A.7 Performance Targets

| Metric | Target |
|---------|--------|
| Recognition Accuracy | ≥95% |
| False Positive Rate | <1% |
| False Negative Rate | <5% |
| Idle CPU Usage | <2% |
| Runtime CPU Usage | <5% |
| Calibration CPU Usage | <10% |
| Total Memory Usage | <100 MB |

---

## A.8 Numerical Precision

| Constant | Value |
|----------|-------|
| Floating Point Type | Float64 |
| Covariance Precision | Float64 |
| Confidence Precision | Float64 |
| Matrix Precision | Float64 |

---

## A.9 Runtime Complexity

| Component | Complexity |
|-----------|------------|
| Candidate Detection | O(N) |
| Filtering | O(N) |
| FFT | O(N log N) |
| Feature Extraction | O(N) |
| Classification | O(Z × F²) |
| Validation | O(1) |
| Command Dispatch | O(1) |

Where:

- **N** = Audio Samples
- **F** = Number of Features
- **Z** = Number of Interaction Zones

---

## A.10 Version Information

| Property | Value |
|----------|-------|
| Algorithm Version | 2.1 (event-anchored measurement, ADR-017) |
| Recognition Method | Deterministic Statistical Classification |
| DSP Engine | FFT + Butterworth |
| Classifier | Mahalanobis Distance |
| Runtime Learning | Disabled |
| Cloud Processing | None |
| Device Support | Apple Silicon macOS |

---

## A.11 Canonical Defaults

Unless otherwise specified, implementations claiming compliance with Tapper Algorithm Specification Version 1 shall use the constants defined in this appendix.

These defaults represent the canonical reference implementation.

# Appendix B – Glossary

## B.1 Purpose

This appendix defines the technical terminology used throughout this specification.

Unless otherwise stated, the following definitions apply to all sections of the document.

---

## Attack Time

The elapsed time between the onset of a tap and its peak amplitude.

---

## Ambiguity Margin

The minimum acceptable separation between the two closest statistical matches.

If the separation falls below this margin, the recognition result is classified as **Unknown**.

---

## Calibration

The process of collecting representative tap samples to construct statistical models for each interaction zone.

Calibration occurs only before runtime recognition.

---

## Calibration Profile

The persistent data structure containing all statistical information required for recognition.

It includes:

- Mean Feature Vectors
- Covariance Matrices
- Acceptance Thresholds
- Metadata

---

## Candidate

An acoustic event that has passed initial detection and is undergoing validation.

Not every candidate becomes a recognized tap.

---

## Classification Engine

The subsystem responsible for assigning a validated Feature Vector to the most probable interaction zone.

---

## Confidence Score

A diagnostic measure indicating how closely a candidate matches its recognized interaction zone.

Confidence does **not** affect classification decisions.

---

## Cooldown

A short period following successful recognition during which additional acoustic events are ignored to prevent duplicate recognition.

---

## Covariance Matrix

A statistical matrix describing the variance and correlation of all features within an interaction zone.

Used by the Mahalanobis Distance calculation.

---

## Deterministic Recognition

A recognition approach in which identical inputs always produce identical outputs.

No randomness or adaptive learning is involved.

---

## Digital Signal Processing (DSP)

The sequence of mathematical operations applied to raw microphone audio prior to feature extraction.

---

## Dominant Frequency

The frequency component with the greatest spectral magnitude.

---

## Feature

A measurable numerical property extracted from an acoustic event.

Examples include RMS Energy, Spectral Centroid, and Attack Time.

---

## Feature Extraction

The process of converting filtered audio into a Feature Vector.

---

## Feature Vector

The canonical numerical representation of a tap.

Version 1 consists of ten acoustic features.

---

## FFT (Fast Fourier Transform)

An efficient algorithm for converting time-domain signals into the frequency domain.

---

## Hann Window

A windowing function applied prior to FFT computation to reduce spectral leakage.

---

## Interaction Zone

A predefined physical region of the laptop chassis capable of generating a unique acoustic signature.

Version 1 defines four interaction zones.

---

## Mahalanobis Distance

A multivariate statistical distance metric that accounts for feature variance and correlation.

Used as the primary classification metric.

---

## Mean Feature Vector

The average Feature Vector computed during calibration for an interaction zone.

Represents the expected acoustic signature.

---

## Noise Floor

The ambient acoustic energy measured when no intentional tap is present.

Used during candidate validation.

---

## Peak Amplitude

The maximum absolute sample value within a tap waveform.

---

## Recognition Engine

The complete runtime subsystem responsible for detecting, validating, classifying, and executing tap events.

---

## Resonance

The natural vibration characteristics of the laptop chassis following an impact.

---

## RMS Energy

The Root Mean Square energy of an acoustic event.

Represents overall signal power.

---

## Runtime State Machine

The deterministic finite-state machine governing recognition behavior.

---

## Signal Duration

The total time during which the acoustic event remains above the detection threshold.

---

## Spectral Bandwidth

The spread of spectral energy around the spectral centroid.

---

## Spectral Centroid

The weighted average frequency of the signal spectrum.

Often interpreted as the "center of mass" of spectral energy.

---

## Spectral Roll-off

The frequency below which a specified percentage of spectral energy is contained.

---

## Threshold

The maximum acceptable Mahalanobis Distance for recognizing a tap as belonging to an interaction zone.

---

## Unknown

A classification result indicating that no interaction zone matched the observed Feature Vector with sufficient confidence.

---

## Validation

The process of verifying that an acoustic event satisfies all requirements necessary for statistical classification.

---

## Zero Crossing Rate

The rate at which the audio waveform crosses the zero-amplitude axis.

Often used as an indicator of signal complexity.

# Appendix C – References

## C.1 Purpose

This appendix lists the primary mathematical, signal processing, and software engineering references that informed the design of the Tapper Recognition Engine.

These references provide theoretical justification for the algorithms and engineering practices described throughout this specification.

---

# C.2 Digital Signal Processing

Oppenheim, A. V., Schafer, R. W., & Buck, J. R.

**Discrete-Time Signal Processing**

Prentice Hall.

Widely regarded as the standard reference for digital signal processing, including digital filters, FFTs, window functions, and spectral analysis.

---

Proakis, J. G., & Manolakis, D. G.

**Digital Signal Processing: Principles, Algorithms, and Applications**

Pearson.

Provides mathematical foundations for digital filtering, frequency analysis, and real-time DSP implementation.

---

Smith, Steven W.

**The Scientist and Engineer's Guide to Digital Signal Processing**

California Technical Publishing.

Practical reference covering FFTs, filtering, and signal analysis.

---

# C.3 Statistical Pattern Recognition

Mahalanobis, P. C. (1936)

**On the Generalized Distance in Statistics**

Proceedings of the National Institute of Sciences of India.

Introduces the Mahalanobis Distance used throughout the Tapper recognition algorithm.

---

Bishop, Christopher M.

**Pattern Recognition and Machine Learning**

Springer.

Reference for statistical classification concepts and multivariate analysis.

---

Duda, Hart & Stork

**Pattern Classification**

Wiley.

Foundational text covering deterministic statistical classifiers and multivariate decision theory.

---

# C.4 Numerical Methods

Golub, Gene H.

**Matrix Computations**

Johns Hopkins University Press.

Reference for covariance matrices, matrix inversion, and numerical stability.

---

Higham, Nicholas J.

**Accuracy and Stability of Numerical Algorithms**

SIAM.

Provides guidance for floating-point precision and stable numerical computation.

---

# C.5 Signal Analysis

Harris, F. J.

**On the Use of Windows for Harmonic Analysis with the Discrete Fourier Transform**

Proceedings of the IEEE.

Classic reference comparing Hann, Hamming, Blackman, and other window functions.

---

Cooley, J. W., & Tukey, J. W.

**An Algorithm for the Machine Calculation of Complex Fourier Series**

Mathematics of Computation.

Original publication introducing the Fast Fourier Transform algorithm.

---

# C.6 Apple Technologies

Apple Inc.

**AVAudioEngine Documentation**

Official reference for macOS real-time audio capture and processing.

---

Apple Inc.

**Accelerate Framework Documentation**

Reference for high-performance FFTs, vector mathematics, and DSP operations.

---

Apple Inc.

**Core Audio Documentation**

Reference for low-latency audio processing on macOS.

---

Apple Inc.

**Human Interface Guidelines**

Reference for responsive interaction design and perceived latency expectations.

---

# C.7 IEEE Standards

IEEE Computer Society.

**IEEE Standard for Floating-Point Arithmetic (IEEE 754)**

Reference for floating-point numerical representation used throughout the recognition engine.

---

# C.8 Software Engineering

Gamma, Helm, Johnson & Vlissides

**Design Patterns: Elements of Reusable Object-Oriented Software**

Reference for modular subsystem architecture.

---

Martin, Robert C.

**Clean Architecture**

Reference for layered software architecture and subsystem separation.

---

# C.9 Version Reference

This specification corresponds to:

**Tapper Recognition Algorithm Specification**

Version 1.0

The references listed above provide theoretical support for the deterministic DSP pipeline, statistical classification methodology, and software architecture described throughout this document.

