# 13_UI_UX_SPECIFICATION.md

> **Tapper — UI / UX Specification**
>
> Version: 1.0

---

# 1. Purpose

This document is the single source of truth for the user experience and visual design of Tapper.

Goals:

- Native macOS experience
- Functional before decorative
- Deterministic and transparent
- Fast to navigate
- Professional engineering aesthetic
- Consistent across all screens

---

# 2. Design Philosophy

Tapper should feel like a first-party macOS utility.

The interface must:

- Follow Apple's Human Interface Guidelines.
- Minimize visual clutter.
- Explain system behavior.
- Never hide important state.
- Always provide user feedback.

The UI should build trust by making the recognition engine explainable rather than mysterious.

---

# 3. Design Language

Keywords:

- Native
- Minimal
- Technical
- Calm
- Professional
- Precise
- Modern
- Utility-first

Avoid:

- Neon effects
- Skeuomorphism
- Excessive animation
- Gaming aesthetics
- Dashboard overload

---

# 4. Window

Type:
- Standard macOS settings window

Minimum size:
- 1200 × 760 px

Resizable:
- Yes

Sidebar:
- Fixed width (~240 px)

Content:
- Adaptive

---

# 5. Navigation

Sidebar sections:

- Dashboard
- Calibration
- Actions
- Profiles
- Testing
- Diagnostics
- Settings
- About

Navigation persists between launches.

---

# 6. Dashboard

Displays:

- Enable / Disable Toggle
- Listening Status
- Current Profile
- CPU Usage
- Recognition Latency
- Last Tap
- Last Executed Command

Primary element:

A centered MacBook visualization showing four tap zones.

Each zone:

- Hover highlight
- Click to inspect mapping
- Green flash when detected
- Red flash when rejected

Quick actions:

- Start Calibration
- Test Recognition
- Open Settings

---

# 7. Calibration

Wizard-based workflow.

For each zone:

1. Display highlighted target region.
2. Explain where to tap.
3. Record 20 accepted taps.
4. Show live progress.
5. Display quality score.
6. Allow retry.

Progress bar:

Zone 1/4
↓

20 taps

↓

Next Zone

Calibration summary:

- Average signal quality
- Variance
- Recommendation

---

# 8. Actions

Each zone card contains:

- Zone Name
- Current Action
- Action Type
- Configure
- Test
- Delete

Supported action types:

- Keyboard Shortcut
- Apple Shortcut
- AppleScript
- Shell Command
- Executable
- Launch App
- Open URL
- Open File
- Open Folder

One action per zone in V1.

---

# 9. Profiles

Supports:

- Default
- Work
- Gaming
- Presentation

V1 activates only one profile at a time.

Future versions may support automatic switching.

---

# 10. Testing

Purpose:

Provide real-time recognition feedback.

Display:

- Tap Accepted / Rejected
- Zone
- Similarity Score
- Confidence
- Processing Time
- Signal Energy
- Noise Floor
- Rejection Reason

Include a scrolling event log.

---

# 11. Diagnostics

Displays:

- Recognition History
- False Positives
- False Negatives
- CPU Usage
- Memory Usage
- Sample Rate
- Buffer Size
- Calibration Status
- Permissions

Button:

Export Diagnostics Bundle

---

# 12. Settings

General

- Enable Tapper
- Launch at Login
- Global Shortcut
- Notifications

Recognition

- Cooldown
- Sensitivity (future)
- Reset Calibration

Privacy

- Diagnostics Export

Advanced

- Debug Logging
- Developer Mode

---

# 13. About

Display:

- Version
- Build Number
- License
- Documentation
- Credits

---

# 14. Global Shortcut

Default:

⌘⌥T

Configurable.

Detect conflicts with existing shortcuts.

---

# 15. Color System

Support:

- Light Mode
- Dark Mode

Semantic colors:

Accent:
System Blue

Success:
Green

Warning:
Orange

Error:
Red

Information:
Blue

Backgrounds:

Primary
Secondary
Grouped

Use native macOS semantic colors wherever possible.

---

# 16. Typography

Font:

SF Pro

Diagnostics:

SF Mono

Hierarchy:

Large Title

Title

Headline

Body

Caption

---

# 17. Layout

Grid:

8 pt

Corner Radius:

12 pt

Cards:

24 pt padding

Section spacing:

32 pt

---

# 18. Animations

Duration:

Fast:
0.15 s

Normal:
0.25 s

Slow:
0.40 s

Animations:

- Sidebar transitions
- Hover states
- Zone flash
- Progress
- Modal transitions

Respect "Reduce Motion".

---

# 19. Accessibility

Support:

- VoiceOver
- Keyboard Navigation
- High Contrast
- Reduce Motion
- Dynamic Type compatibility

All controls require accessibility labels.

---

# 20. Empty States

Examples:

No Calibration

"No calibration profile available."

Permission Denied

"Microphone permission is required."

No Actions

"No command assigned."

---

# 21. Error States

Recognition Failure

Calibration Failure

Permission Revoked

Command Execution Failure

Display:

Problem

Cause

Suggested Recovery

---

# 22. Explainability

Every recognition must expose:

Accepted:

- Zone
- Similarity Score
- Processing Time
- Signal Strength

Rejected:

- Reason
- Noise Level
- Threshold
- Candidate Features

Users should understand WHY a tap was accepted or rejected.

---

# 23. Component Library

Reusable components:

- Sidebar
- Status Card
- Metric Card
- Toggle
- Zone Card
- Laptop Visualization
- Progress Bar
- Event Row
- Diagnostics Row
- Action Card
- Confirmation Dialog
- Permission Banner

---

# 24. Design Tokens

Spacing:

XS = 4
S = 8
M = 16
L = 24
XL = 32

Radius:

Small = 8

Standard = 12

Large = 20

Animation:

Fast = 0.15 s

Normal = 0.25 s

Slow = 0.40 s

---

# 25. Notifications

Success

Calibration Complete

Command Failed

Permission Lost

Recognition Disabled

Use native macOS notifications.

---

# 26. Future UI

Reserved:

- Multi-tap editor
- Gesture designer
- Plugin marketplace
- Analytics dashboard
- Per-app mappings
- External microphones

---

# 27. Acceptance Criteria

A compliant UI shall:

✓ Feel native on macOS.

✓ Support Light and Dark mode.

✓ Be keyboard accessible.

✓ Explain recognition results.

✓ Keep navigation under two clicks.

✓ Never obscure recognition status.

✓ Provide deterministic, transparent feedback.

✓ Preserve consistency across all screens.

---

# End of Document
