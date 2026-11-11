#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo "App Attest Decoder requires macOS." >&2; exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
  echo "Install Xcode 26 or newer, select it in Xcode > Settings > Locations, and run this command again." >&2
  exit 1
fi
SWIFT_VERSION="$(swift --version | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -n 1)"
if ! awk -v version="$SWIFT_VERSION" 'BEGIN { split(version,v,"."); exit !(v[1]>6 || (v[1]==6 && v[2]>=2)) }'; then
  echo "Swift 6.2+ is required; found ${SWIFT_VERSION:-unknown}. Install/select Xcode 26+." >&2; exit 1
fi
if ! /usr/bin/python3 --version >/dev/null 2>&1; then
  echo "Apple's Python 3 is needed for attestation decoding. Install/select the Xcode Command Line Tools." >&2; exit 1
fi
if [[ ! -x /usr/bin/openssl ]]; then
  echo "The macOS OpenSSL command is missing." >&2; exit 1
fi
