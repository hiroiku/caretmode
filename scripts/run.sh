#!/bin/bash
set -e
cd "$(dirname "$0")/.."

# Stop existing process
pkill -f CaretMode 2>/dev/null || true
sleep 0.5

# Regenerate project + build
xcodegen generate 2>&1 | tail -1
xcodebuild -project CaretMode.xcodeproj -scheme CaretMode -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/dist" build 2>&1 | tail -1

# Reset accessibility & input monitoring permissions for this bundle ID
tccutil reset Accessibility com.hiroiku.CaretMode 2>/dev/null || true
tccutil reset ListenEvent com.hiroiku.CaretMode 2>/dev/null || true

echo "Opening CaretMode..."
open dist/CaretMode.app
