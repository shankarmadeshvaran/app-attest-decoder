#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -parse-as-library Sources/AppAttestDecoder/Models/DecoderDraft.swift \
    Sources/AppAttestDecoder/Stores/DecoderDraftStore.swift \
    Tests/SwiftDataPersistenceCheck.swift -o "$TEST_DIR/check"
"$TEST_DIR/check" write "$TEST_DIR/drafts.store"
"$TEST_DIR/check" read "$TEST_DIR/drafts.store"
"$TEST_DIR/check" clear "$TEST_DIR/drafts.store"
"$TEST_DIR/check" read-cleared "$TEST_DIR/drafts.store"
