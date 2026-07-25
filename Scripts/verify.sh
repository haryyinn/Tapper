#!/usr/bin/env bash
#
# Verification gate: build with warnings-as-errors, then lint.
# Exits non-zero if either fails, so a broken tree can never reach a commit.
#
# Build output is written to a log rather than piped, because piping the
# compiler through another command masks its exit status.
set -euo pipefail

cd "$(dirname "$0")/.."
LOG="$(mktemp -t tapper-build)"

if ! swift build -Xswiftc -warnings-as-errors >"$LOG" 2>&1; then
    echo "BUILD FAILED"
    grep -E 'error:' "$LOG" | head -20 || tail -20 "$LOG"
    rm -f "$LOG"
    exit 1
fi
rm -f "$LOG"
echo "build: OK"

./Scripts/lint.sh
echo "lint: OK"
