# App Attest Decoder — AI Handoff Guide

This file is the starting point for an AI agent, contributor, or maintainer working on this repository. Read it before changing code, documentation, tests, release artifacts, or repository visibility.

## Project purpose

App Attest Decoder is a local-first macOS developer tool for inspecting and validating Apple App Attest data. It has two independent workspaces:

1. **Attestation Decoder** decodes an App Attest attestation CBOR object, including authenticator data, certificates, receipt data, and the attested public key.
2. **Assertion Decoder** decodes and verifies the CBOR assertion returned by `DCAppAttestService.generateAssertion(_:completionHandler:)`.

The application is a debugging and verification aid. It does not contact a server, send telemetry, upload input, or replace the server-side verification required in a production App Attest integration.

## Technology stack

| Area | Technology | Purpose |
| --- | --- | --- |
| Desktop UI | SwiftUI | Native macOS interface and navigation between decoders. |
| Local persistence | SwiftData | Saves decoder drafts locally; CloudKit synchronization is disabled. |
| Assertion cryptography | CryptoKit | P-256 public-key parsing, SHA-256, DER ECDSA signature parsing, and signature verification. |
| Attestation decoding | Python 3 standard library plus OpenSSL | Parses CBOR/DER and verifies or decodes the receipt used by the Attestation Decoder. |
| Build system | Swift Package Manager | Builds the executable, embeds resources, and runs tests. |
| Automation | shell scripts and GitHub Actions | Provides reproducible environment checks, tests, packaging, and CI. |

There are no third-party Swift package dependencies.

## System requirements

- macOS 14 Sonoma or later.
- Xcode 26 or later, including the command-line tools and Swift 6.2 or later.
- Apple system Python at `/usr/bin/python3`.
- OpenSSL available to the bundled Python decoder.

## Install and run

The supported way to build and run is Xcode:

```sh
git clone https://github.com/shankarmadeshvaran/app-attest-decoder.git
cd app-attest-decoder
open AppAttestDecoder.xcodeproj
```

Select the **AppAttestDecoder** scheme and **My Mac**, and press ⌘R. No development team is required (ad-hoc "Sign to Run Locally", no App Sandbox because the app runs `/usr/bin/python3`). `Package.swift` builds the same sources and can also be opened in Xcode; `Bundle.appResources` resolves resources from `Bundle.module` under SwiftPM and `Bundle.main` under the Xcode project. Regenerate the project with `python3 script/generate_xcodeproj.py .` after adding, removing, or renaming files in `Sources/AppAttestDecoder`; CI verifies it is current.

There are no install or packaging scripts; do not add them unless the maintainer asks. Run the automated checks with:

```sh
./script/test.sh
```

## How to use the application

### Attestation Decoder

1. Paste an attestation object as hexadecimal or Base64.
2. Optionally enter the app identifier as `TeamID.BundleID`.
3. Decode the object to inspect authenticator data, AAGUID, credential ID, COSE key, certificates, receipt, and status checks.
4. Copy report fields when comparing them with device or server logs.

The decoder extracts the P-256 coordinate values `x` and `y` from the attestation COSE key. Those values are shared with the Assertion Decoder when available.

### Assertion Decoder

1. Enter the assertion returned by `generateAssertion` as hexadecimal or Base64.
2. Supply the attested public key from the attestation object. Enter either the 65-byte X9.63 point (`04 || x || y`) or its 32-byte `x` and `y` coordinates. If coordinates are supplied, the app builds the X9.63 point by prefixing `04`.
3. Enter the Key ID only for the SHA-256/Base64 sanity check. A Key ID is **not** a P-256 public key.
4. Enter either the exact client-data text (the five application-defined lines joined with LF and no trailing LF) or its 64-character SHA-256 hash.
5. Optionally enter the App ID and a previous counter.
6. Verify the assertion and inspect the Key ID check, RP ID hash, flags, counter, client-data hash, nonce, and final result.

For a safe manual check, use the built-in synthetic example. Never add live customer, organization, device, certificate, receipt, assertion, nonce, URL, Team ID, bundle ID, or log data to fixtures, screenshots, documentation, commits, releases, issues, or pull requests.

## Assertion verification contract

The implementation in `Sources/AppAttestDecoder/Services/AssertionSignatureVerifier.swift` must preserve this contract unless it is deliberately changed with updated tests and documentation:

1. Parse assertion CBOR as a map with the `signature` and `authenticatorData` byte strings. Use only the `signature` byte string as the DER ECDSA signature.
2. Require exactly 37 bytes of authenticator data: 32-byte RP ID hash, one flags byte, and a four-byte big-endian counter.
3. Construct `clientDataHash` from the entered 64-character hash, or calculate `SHA256(UTF8(clientData))`.
4. Calculate `nonce = SHA256(authenticatorData || clientDataHash)`.
5. Construct `P256.Signing.PublicKey(x963Representation: point)` from the 65-byte public-key point.
6. Check `base64(SHA256(point)) == keyId` before cryptographic verification when a Key ID is supplied. Stop with “public key does not match Key ID” if it differs.
7. Parse `P256.Signing.ECDSASignature(derRepresentation: signatureBytes)`.
8. Call `key.isValidSignature(signature, for: nonce)`. Pass `nonce` as the message, not `authenticatorData || clientDataHash`, and do not use a prehashed overload.
9. When supplied, compare `rpIdHash` with `SHA256(TeamID.BundleID)` and require the counter to exceed a supplied previous counter.

CryptoKit hashes the `nonce` message for ECDSA-SHA256. Altering this behavior changes verification semantics and can make valid App Attest assertions fail.

## Repository map

```text
Package.swift                                      SwiftPM manifest and resource declarations
AppAttestDecoder.xcodeproj/                        Xcode project (generated by script/generate_xcodeproj.py)
XcodeSupport/Info.plist                            Extra Info.plist keys for the Xcode app target
Sources/AppAttestDecoder/App/                      App entry point and SwiftData model container
Sources/AppAttestDecoder/Views/                    SwiftUI screens and reusable report components
Sources/AppAttestDecoder/Models/                   Codable/display and SwiftData models
Sources/AppAttestDecoder/Stores/                   SwiftData draft storage
Sources/AppAttestDecoder/Services/                 Decoding, CBOR parsing, and assertion verification
Sources/AppAttestDecoder/Resources/                Bundled Python decoder, sample data, icon
docs/App_Attest_Verification_Guide.pdf             App Attest flow guide (contains Apple diagrams, © Apple)
script/test.sh                                     Full test entry point
script/test_assertion.sh                           Native assertion test vector check
script/test_persistence.sh                         SwiftData persistence check
script/generate_xcodeproj.py                       Regenerates the Xcode project from the source tree
Tests/                                             Python/decoder automated tests
.github/workflows/ci.yml                           macOS continuous integration
```

`Sources/AppAttestDecoder/Resources/appattest_decode.py` is the attestation decoder bundled into the app; `DecoderService` runs it with `/usr/bin/python3`. It can also be run directly from the command line.

## Data flow and state

- `WorkspaceView` owns the shared App ID and keeps both decoders mounted so that shared values remain synchronized.
- `ContentView` coordinates the Attestation Decoder and invokes `DecoderService`, which runs the bundled Python tool.
- `AssertionVerificationInputsView` gathers assertion-specific inputs. `AssertionSignatureVerifier` performs all native assertion parsing and CryptoKit verification.
- `DecoderDraftStore` persists user-entered fields in SwiftData. Persistence is local only (`cloudKitDatabase: .none`).
- Decoder reports use explicit statuses: **Matches**, **Mismatch**, **Decoded**, **Not checked**, and **Unavailable**. Maintain those meanings consistently in UI and exported/copyable reports.

## Working rules for AI agents

1. Inspect `git status` before editing. This workspace may contain user changes; preserve unrelated work.
2. Read the relevant source and test before modifying behavior. Avoid broad rewrites for a focused defect or UI request.
3. Keep attestation decoding and assertion verification separate. The Python decoder supports attestation objects; assertion verification is native Swift/CryptoKit.
4. Prefer standard SwiftUI and SwiftData APIs. Keep the app local-first and dependency-free unless the user explicitly asks to change that scope.
5. Show large decoded values fully or provide a nearby Copy action. Never silently crop security-relevant values.
6. Keep public-key handling precise: coordinates are 32-byte values; an X9.63 point is `04 || x || y`; Key ID is a SHA-256/Base64 identifier, never a key encoding.
7. If changing cryptographic verification, add or update deterministic synthetic test vectors and run the assertion test before reporting completion.
8. If changing persistence models or inputs, run the persistence test and preserve migration-safe defaults.
9. Update this file and the README when a setup command, architecture boundary, supported input form, or security behavior changes.
10. Use synthetic fixtures only. Treat all real App Attest material as sensitive even if it appears encoded.

## Validation expectations

Run the narrowest meaningful command while iterating, then run the relevant broader checks before handoff:

```sh
./script/test_assertion.sh      # Required after assertion parser/verifier changes
./script/test_persistence.sh    # Required after SwiftData model/store/input changes
./script/test.sh                # Required before a release or broad handoff
xcodebuild -project AppAttestDecoder.xcodeproj -scheme AppAttestDecoder build  # Required when changing project files or resources
```

For UI work, launch the app and exercise both sidebar destinations, shared App ID synchronization, input persistence, report status rendering, and Copy actions for long values.

## Privacy and publication gate

- Use synthetic fixtures only. Never commit, attach, screenshot, paste, log, or package real attestation or assertion data, certificates, receipts, Team IDs, bundle IDs, nonces, URLs, or logs.
- Use generic placeholders such as `EXAMPLETEAM.com.example.demo` or `TEAMID.com.example.app` for app identifiers in code, tests, and documentation.
- Before any commit, tag, release, CI artifact, screenshot, issue, or pull request, scan the changed files for sensitive values.
- Do not rewrite Git history, force-push, change repository visibility, create releases, or upload artifacts unless the maintainer explicitly requests that action.

## Definition of done

A change is complete when it is small enough to review, preserves the verification contract and privacy boundary, updates relevant documentation, and passes the validation appropriate to the files changed. Report the files changed, the commands run, and any limitation that remains.
