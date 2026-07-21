#!/usr/bin/env bash
#
# Format Swift sources in place with Apple's bundled swift-format.
set -euo pipefail

cd "$(dirname "$0")/.."
swift format --in-place --recursive Package.swift Sources Tests
