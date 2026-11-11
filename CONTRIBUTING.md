# Contributing

Bug fixes, UI improvements, documentation, and independently generated test vectors are welcome.

1. Fork and clone the repository.
2. Install/select Xcode 26+ (Swift 6.2+).
3. Open `AppAttestDecoder.xcodeproj` and press ⌘R, or run `./script/build_and_run.sh`.
4. Run `./script/test.sh` before opening a pull request. If you add, remove, or rename a
   source or resource file, run `python3 script/generate_xcodeproj.py .` and commit the result.

Keep decoding logic out of views. Use CryptoKit for assertion verification and
SwiftData on the main actor for drafts. Preserve exact signed bytes; never silently
trim, reorder, or normalize clientData. The assertion test vector must stay VALID.
Add a failing regression test for changes to signature or CBOR handling.

The Python attestation decoder bundled into the app is
`Sources/AppAttestDecoder/Resources/appattest_decode.py`.

Use synthetic examples in issues, screenshots, tests, and pull requests. Never commit
private keys, credentials, real client payloads, local databases, or personal drafts.
