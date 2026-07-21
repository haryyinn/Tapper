// Tapper
//
// Root module for the Tapper macOS utility.
//
// Tapper recognizes intentional taps on the MacBook chassis using the built-in
// microphone and executes user-configured commands. Recognition is fully local,
// offline, and deterministic.
//
// This module currently defines no runtime types. The recognition pipeline —
// Audio Acquisition → Signal Processing → Tap Detection → Zone Classification →
// Command Mapping → Command Execution — is introduced subsystem by subsystem in
// the phases that follow, each as its own target under Sources/. See the
// authoritative reference under Docs/.
