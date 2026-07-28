#!/usr/bin/env bash
#
# Assembles Tapper.app from the SwiftPM executable target.
#
# macOS attributes Microphone and Accessibility permissions (TCC) to a signed
# bundle, not to a loose binary, so empirical validation requires a real .app.
# This script produces one without needing Xcode: it builds the package, lays
# out the bundle, installs Info.plist, and ad-hoc signs the result.
#
# Usage:
#   ./Scripts/build-app.sh [--release]
#
# Then:
#   open build/Tapper.app
#
# Calibration and validation run inside the application (Calibration and
# Validation tabs). They are not shell commands: macOS attributes microphone
# access to the launched app bundle, not to a binary executed from a terminal.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIGURATION="release"
fi

echo "building package (${CONFIGURATION})..."
swift build -c "$CONFIGURATION" --product TapperApp >/dev/null

BINARY="$(swift build -c "$CONFIGURATION" --product TapperApp --show-bin-path)/TapperApp"
if [[ ! -x "$BINARY" ]]; then
    echo "executable not found at $BINARY"
    exit 1
fi

APP="build/Tapper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/Tapper"
cp Resources/App/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature. Sufficient for local validation on this machine; a
# Developer ID signature is required for distribution.
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1

echo "built $APP"
codesign -dv "$APP" 2>&1 | sed -n '1,3p'
echo
echo "launch:  open $APP"
echo
echo "Calibration and validation are tabs inside the app."
echo "Optional live trace:"
echo "  log stream --predicate 'subsystem == \"com.tapper.Tapper\"' --info"
