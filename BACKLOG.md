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
