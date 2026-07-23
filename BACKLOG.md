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
