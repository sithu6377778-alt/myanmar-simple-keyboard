#!/bin/bash
# Runs the EComposer unit tests on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -O -target "$(uname -m)-apple-macos15.0" \
  Sources/Core/*.swift Tests/main.swift -o build/core-tests
build/core-tests
