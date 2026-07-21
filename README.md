# Tapper

A native macOS (Apple Silicon, macOS 14+) background utility that recognizes
intentional taps on the MacBook chassis using the built-in microphone and
executes user-configured commands. Recognition is fully local, offline, and
deterministic — no AI, no ML, no networking, no telemetry.

> Status: **Phase 0 (Bootstrap).** This establishes a clean, buildable Swift
> Package. The recognition pipeline is implemented subsystem by subsystem in
> later phases. See `Docs/IMPLEMENTATION_PLAN.md`.

## Requirements

- macOS 14+ on Apple Silicon
- Swift 6 toolchain (Swift 6.0+)
- Full Xcode is required to run the XCTest suite locally (`swift test`). With
  Command Line Tools only, `swift build` works but XCTest is unavailable; the
  test suite runs in CI on a macOS runner with Xcode.

## Build, test, and lint

```bash
# Build (warnings treated as errors)
swift build -Xswiftc -warnings-as-errors

# Test (requires full Xcode locally; always run in CI)
swift test

# Lint / format (Apple's bundled swift-format)
./Scripts/lint.sh
./Scripts/format.sh
```

CI runs `swift build`, `swift test`, and `swift format lint` on every push and
pull request (`.github/workflows/ci.yml`).

## Documentation

The `Docs/` directory is the authoritative engineering reference and the single
source of truth. Start with `CLAUDE.md` and `DEVELOPMENT_PROTOCOL.md`, then read
the documents relevant to the task. Documentation takes precedence over code.
