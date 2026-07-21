# Tapper V1 - DSP Parameters (Initial Specification)

> These values define the baseline Digital Signal Processing (DSP) pipeline for Tapper V1. They are selected based on standard audio DSP practices and expected MacBook chassis acoustics. These values are considered the initial engineering defaults and may be refined through empirical testing and beta validation.

---

## 1. Sample Rate

**Definition**

The number of audio samples captured from the microphone every second.

**Purpose**

Determines the temporal resolution of the captured signal.

**Value**

48,000 Hz

**Reasoning**

- Native sample rate on modern Apple hardware
- High temporal resolution for transient events
- Avoids unnecessary resampling
- Minimal performance overhead on Apple Silicon

**Configurable**

No

---

## 2. Buffer Size

**Definition**

The number of audio samples processed in a single DSP iteration.

**Purpose**

Controls the balance between processing latency and CPU usage.

**Value**

256 samples

**Equivalent Duration**

≈ 5.33 ms @ 48 kHz

**Reasoning**

- Excellent real-time responsiveness
- Low processing latency
- Standard low-latency audio buffer size

**Configurable**

No

---

## 3. Analysis Window Size

**Definition**

The duration of audio analyzed as a single observation.

**Purpose**

Captures both the initial impact and early resonance of a tap.

**Value**

40 ms

**Reasoning**

- Long enough to include the transient and ringing
- Short enough for low latency
- Suitable for chassis impulse analysis

**Configurable**

No

---

## 4. Window Overlap

**Definition**

The percentage of overlap between consecutive analysis windows.

**Purpose**

Prevents taps from being split between windows and improves temporal resolution.

**Value**

50%

**Reasoning**

- Standard DSP practice
- Improves robustness
- Reduces missed detections

**Configurable**

No

---

## 5. Window Function

**Definition**

The mathematical weighting applied before performing frequency-domain analysis.

**Purpose**

Reduces spectral leakage before FFT computation.

**Value**

Hann Window

**Reasoning**

- Excellent general-purpose window
- Widely used for transient analysis
- Low spectral leakage

**Configurable**

No

---

## 6. Band-Pass Filter

**Definition**

Digital filter used to remove unwanted frequency content before feature extraction.

**Purpose**

Suppresses environmental noise while preserving tap characteristics.

**Type**

4th Order Butterworth IIR

**Passband**

300 Hz – 6000 Hz

**Reasoning**

Removes:

- HVAC rumble
- Desk vibrations
- Low-frequency handling noise
- Very high-frequency electrical noise

Preserves:

- Impact energy
- Resonance frequencies
- Chassis vibration signature

**Configurable**

No

---

## 7. Signal Normalization

**Definition**

Normalize incoming audio amplitude before feature extraction.

**Purpose**

Reduce sensitivity to differences in tap force.

**Method**

Peak normalization to [-1, 1]

**Configurable**

No

---

## 8. Feature Vector

Each accepted tap is represented by the following engineered features.

1. Peak Amplitude
2. RMS Energy
3. Spectral Centroid
4. Spectral Roll-off
5. Spectral Bandwidth
6. Dominant Frequency
7. Zero Crossing Rate
8. Attack Time
9. Decay Time
10. Signal Duration

**Feature Vector Size**

10 Features

**Purpose**

Compact numerical representation of a tap.

**Configurable**

No

---

## 9. FFT Parameters

FFT Size

2048 Samples

Purpose

Frequency-domain analysis.

Reasoning

Provides sufficient frequency resolution while maintaining acceptable computation time.

---

## 10. Similarity Metric

**Definition**

Algorithm used to compare an observed tap against calibrated zone profiles.

**Method**

Mahalanobis Distance

**Reasoning**

Accounts for:

- Mean
- Variance
- Covariance

Produces statistically robust deterministic classification.

Chosen over:

- Euclidean Distance
- Cosine Similarity

**Configurable**

No

---

## 11. Classification Strategy

For every detected tap:

1. Extract Feature Vector
2. Compute Mahalanobis Distance to each calibrated zone
3. Select minimum distance
4. Compare against acceptance threshold
5. Execute mapped command if accepted
6. Reject otherwise

---

## 12. Acceptance Threshold

**Definition**

Maximum allowable Mahalanobis Distance for a valid recognition.

**Method**

Calibration-derived threshold.

Compute:

Threshold = Mean Distance + (2 × Standard Deviation)

Threshold is computed independently for every calibrated zone.

**Reasoning**

Automatically adapts to each user's tapping behaviour while remaining deterministic.

**Configurable**

No

---

## 13. Detection Cooldown

**Definition**

Minimum time after a successful recognition before another tap can be accepted.

**Purpose**

Prevent duplicate detections caused by chassis resonance.

**Default Value**

200 ms

**Allowed Range**

100–500 ms

**User Adjustable**

Yes

---

## 14. Calibration Sample Count

**Definition**

Number of accepted taps required per zone.

**Value**

20 taps per zone

Four Zones

Total:

80 accepted calibration taps

**Reasoning**

Provides sufficient statistical variance estimation while keeping calibration reasonably short.

---

## 15. Calibration Algorithm

For each zone:

1. Highlight target zone.
2. Collect 20 accepted taps.
3. Reject obvious outliers.
4. Extract feature vector from every accepted tap.
5. Compute mean feature vector.
6. Compute covariance matrix.
7. Derive acceptance threshold.
8. Save zone profile.

Repeat for all four zones.

---

## 16. Feature Extraction Pipeline

For every analysis window:

1. Acquire audio buffer
2. Normalize signal
3. Apply Butterworth Band-Pass Filter
4. Apply Hann Window
5. Compute FFT
6. Extract spectral features
7. Extract temporal features
8. Assemble Feature Vector
9. Compare against calibration profiles
10. Classify using Mahalanobis Distance

---

## 17. Processing Targets

Average Recognition Latency

< 50 ms

Maximum Acceptable Latency

100 ms

CPU Usage

< 5%

Memory Usage

< 100 MB

False Positive Rate

< 1%

False Negative Rate

< 5%

Recognition Accuracy (Post Calibration)

> 95%

---

## 18. Future Tunable Parameters

The following values may be adjusted during beta testing but are fixed for Version 1.

- Band-Pass Frequency Limits
- FFT Size
- Feature Selection
- Acceptance Threshold Multiplier
- Cooldown Duration
- Window Size
- Similarity Threshold
- Feature Weighting
- Noise Rejection Parameters
- Outlier Detection Sensitivity

No parameter tuning shall alter the deterministic nature of the recognition engine.