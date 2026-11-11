# Releasing

1. Run `./script/test.sh` and verify the built-in example is VALID.
2. Run `./script/build_and_run.sh --package`.
3. Run the install script from a fresh clone in a path containing spaces.
4. Check `codesign --verify --deep --strict "dist/App Attest Decoder.app"`.
5. Publish the source tag and attach the architecture-labeled ZIP and checksum if desired.

A package contains only the architecture of the machine that built it. Do not label
an Apple silicon ZIP universal or Intel-compatible. Locally built ZIPs are ad-hoc
signed, not Developer ID signed or notarized. Recommend cloning and building for
users without developer tools configured to trust a distributed binary.

Never attach the SwiftData store, personal example payloads, .build, or the entire
checkout. Only package the app bundle and public documentation.
