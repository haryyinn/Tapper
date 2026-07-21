# Tapper – Data Flow

## Runtime Flow

User Tap
    ↓
PCM Audio
    ↓
Processed Signal
    ↓
Tap Event
    ↓
Interaction Zone
    ↓
Mapped Command
    ↓
Executed Action

---

## Persistent Data

- User Preferences
- Command Mappings
- Calibration Profiles
- Diagnostic Logs

---

## Ephemeral Data

- PCM Buffers
- Processed Features
- Detection Results
- Classification Results

---

## Ownership

| Data | Owner |
|------|-------|
| Audio Buffer | Audio Acquisition |
| Processed Signal | Signal Processing |
| Tap Event | Tap Detection |
| Interaction Zone | Zone Classification |
| Command Mapping | Configuration Manager |
| Calibration | Configuration Manager |
| Logs | Diagnostics |