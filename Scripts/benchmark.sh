#!/usr/bin/env bash
#
# Builds the package and runs the performance baseline harness.
#
# The harness is not part of the shipped package: it is compiled against the
# built modules so production code carries no benchmarking dependencies.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -Xswiftc -warnings-as-errors >/dev/null
BUILD_DIR=".build/debug"

OBJECTS=$(find \
    "$BUILD_DIR/Runtime.build" \
    "$BUILD_DIR/Audio.build" \
    "$BUILD_DIR/Detection.build" \
    "$BUILD_DIR/Classification.build" \
    "$BUILD_DIR/Calibration.build" \
    "$BUILD_DIR/Commands.build" \
    "$BUILD_DIR/Configuration.build" \
    "$BUILD_DIR/Diagnostics.build" \
    "$BUILD_DIR/SystemIntegration.build" \
    "$BUILD_DIR/Features.build" \
    "$BUILD_DIR/DSP.build" \
    -name '*.o')

BINARY="$(mktemp -d)/tapper-benchmark"
# shellcheck disable=SC2086
swiftc -O -I "$BUILD_DIR/Modules" Scripts/Benchmark/main.swift $OBJECTS -o "$BINARY"
"$BINARY"
