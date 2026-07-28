#!/usr/bin/env bash
#
# Inspects the labelled calibration dataset in feature space (ADR-016 §5).
#
# Offline developer diagnostic. It reads a calibration profile and, optionally,
# an exported validation run, and writes feature-space.svg and
# feature-space.txt. It captures no audio, needs no permissions, and never
# modifies a profile.
#
# Usage:
#   ./Scripts/inspect.sh [profile.json] [validation-run.json]
#
# With no arguments it uses the installed profile and the newest validation run
# in ~/TapperValidation.
set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE="${1:-$HOME/Library/Application Support/Tapper/calibration.json}"
if [[ ! -f "$PROFILE" ]]; then
    echo "no calibration profile at: $PROFILE"
    echo "run calibration in the app first, or pass a path explicitly"
    exit 1
fi

RUN="${2:-}"
if [[ -z "$RUN" ]]; then
    RUN="$(ls -t "$HOME"/TapperValidation/validation-*.json 2>/dev/null | head -1 || true)"
fi

swift build --product TapperInspect >/dev/null
BIN="$(swift build --product TapperInspect --show-bin-path)/TapperInspect"

if [[ -n "$RUN" && -f "$RUN" ]]; then
    echo "profile: $PROFILE"
    echo "run:     $RUN"
    "$BIN" "$PROFILE" "$RUN" "${@:3}"
else
    echo "profile: $PROFILE"
    echo "run:     (none found — inspecting calibration samples only)"
    "$BIN" "$PROFILE" "${@:3}"
fi
