#!/usr/bin/env bash
#
# Lint Swift sources with Apple's bundled swift-format.
# Exits non-zero on any style violation (used by CI and pre-commit checks).
set -euo pipefail

cd "$(dirname "$0")/.."
swift format lint --strict --recursive Package.swift Sources Tests
