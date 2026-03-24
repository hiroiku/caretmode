#!/bin/bash
set -e
cd "$(dirname "$0")"

CERT_NAME="CaretMode Dev"

# Regenerate project + build
xcodegen generate 2>&1 | tail -1
xcodebuild -project CaretMode.xcodeproj -scheme CaretMode \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/dist" \
  build 2>&1 | tail -1

# Re-sign with self-signed certificate to preserve TCC permissions across builds
if security find-identity -p codesigning | grep -q "$CERT_NAME"; then
  codesign --force --sign "$CERT_NAME" --deep dist/CaretMode.app
  echo "Signed with '$CERT_NAME'"
else
  echo "Warning: Certificate '$CERT_NAME' not found in keychain."
  echo "Create it in Keychain Access > Certificate Assistant > Create a Certificate"
  echo "  Name: $CERT_NAME"
  echo "  Type: Code Signing"
fi
