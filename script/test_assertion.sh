#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -parse-as-library Sources/AppAttestDecoder/Models/AssertionVerificationInputs.swift \
    Sources/AppAttestDecoder/Services/AssertionCBOR.swift \
    Sources/AppAttestDecoder/Services/AssertionSignatureVerifier.swift \
    Tests/AssertionSignatureCheck.swift -o "$TEST_DIR/check"
"$TEST_DIR/check"
