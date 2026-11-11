# App Attest Decoder

A local macOS inspector for Apple App Attest attestations and assertions. Find out **which value or verification check failed**, without sending your payloads to a third-party server.

- Inspect authenticator data, certificates, nonces, and receipt fields.
- Verify assertion signatures with CryptoKit and see Key ID, App ID, and counter checks.
- Enter public key x/y coordinates; the app builds `04 || x || y` automatically.
- Compare exact signed clientData or supply clientDataHash directly.
- Copy complete receipt fields and export reports.
- Keep independent drafts locally with SwiftData, with a shared App ID.
- Explore a known-valid example without changing your saved inputs.

## Clone and install

**Build requirements:** a Mac with **Xcode 26+ / Swift 6.2+** selected, Apple's Python 3 at `/usr/bin/python3`, and system OpenSSL. Xcode supplies the developer tools; no paid Apple Developer membership or signing certificate is required. The built app targets **macOS 14+**; the macOS version required to build depends on your Xcode version.

```sh
git clone https://github.com/shankarmadeshvaran/app-attest-decoder.git
cd app-attest-decoder
./script/install.sh
```

This checks the environment, builds a release app for your Mac's architecture, installs it in **`~/Applications/App Attest Decoder.app`**, and opens it. It does not need `sudo`. You can delete the checkout after installation: the Python decoder and example are copied into the app bundle. Keep Apple's Python 3 available for attestation decoding.

If the installer reports an older Swift version, select Xcode 26+ in **Xcode → Settings → Locations → Command Line Tools**, then try again. This project is not an iOS app and requires no provisioning profile or development team.

For a custom destination or to install without launching:

```sh
INSTALL_DIR="$HOME/Applications" OPEN_AFTER_INSTALL=0 ./script/install.sh
```

Builds are ad-hoc signed locally, **not Developer ID signed or notarized**. Cloning and building locally is the recommended installation path. Downloaded binaries may be subject to macOS security checks; the installer does not disable those protections.

## Run from Xcode

```sh
git clone https://github.com/shankarmadeshvaran/app-attest-decoder.git
cd app-attest-decoder
open AppAttestDecoder.xcodeproj
```

1. Select the **AppAttestDecoder** scheme and **My Mac** as the run destination.
2. Press **⌘R**. The app opens as **App Attest Decoder**.

No signing team, provisioning profile, or Apple Developer account is needed: the project signs locally ("Sign to Run Locally") and has no third-party dependencies. The app is not sandboxed because it runs Apple's `/usr/bin/python3` to decode attestation objects.

The same sources also build as a Swift package (`open Package.swift` or `swift build`). After adding, removing, or renaming a file under `Sources/AppAttestDecoder`, regenerate the Xcode project with `python3 script/generate_xcodeproj.py .`; CI fails if it is out of date.

## Try it

Click **Try example** in the toolbar. Its signature report should show **VALID**, counter **1**, and:

```text
clientDataHash: 3800ee016bc6ba2c6e7ccb1aaa5eca0f958bc7ee014ee965ee55b64685ffaa63
nonce: 9a1f2f01c5e17c67bc508668638feb41fd4872c3bbad442d2bcb24ced50e4a0f
```

The example is entirely synthetic. Its complete inputs are in [assertion-example.json](Sources/AppAttestDecoder/Resources/assertion-example.json). No private key is included or needed.

## Decode an attestation

In your iOS app, `DCAppAttestService.attestKey(_:clientDataHash:completionHandler:)` returns the attestation object as `Data`. Log or copy it as hex or Base64, for example `attestationObject.base64EncodedString()`, together with the challenge string you hashed into `clientDataHash`.

1. Choose **Attestation Decoder**.
2. Paste hex or Base64, or import a UTF-8 text file containing it.
3. Optionally enter your app identifier as `TeamID.BundleID` (for example `ABCDE12345.com.example.app`) and the original UTF-8 attestation challenge.
4. Choose **Decode object** (⌘↩).
5. Review the checks: **app id matches rpIdHash** confirms the App ID, **nonce matches challenge** confirms the challenge, and **key id = SHA256(public key)** confirms the credential key.

The report includes authenticator fields, certificate descriptions, nonce comparison, and receipt fields. Binary receipt values use hex. Each receipt field has a copy action; long values expand with **Show full**. Exported reports contain complete values.

The last decoded attestation's COSE public key is saved locally. In Assertion Decoder, **Use attestation key** loads its x/y coordinates and derived Key ID. This extraction does not establish certificate trust.

## Verify an assertion

1. Choose **Assertion Decoder** and paste the assertion as hex or Base64.
2. Enter **x and y**, each 32 bytes of hex. The app automatically prepends `04`. Alternatively leave x/y empty and enter the complete 65-byte point.
3. Enter the Base64 **Key ID**, which is checked against SHA256(public key point). A Key ID is a hash, not a public key; a mismatch stops verification.
4. Enter the signed **clientData** in this tool's five-line format, or select **clientDataHash** and enter exactly 64 hex characters.
5. Optionally supply App ID and a previous UInt32 counter, then decode.

The five-line format is:

```text
METHOD
/path?query
lowercase-hex-SHA256-of-body
timestamp
nonce
```

Use LF separators and **no trailing newline**. Bytes are preserved exactly. If your app signs JSON, binary data, a challenge alone, or another layout, calculate SHA256 of those exact bytes in your application and use **clientDataHash** instead. Never reserialize JSON to guess the original bytes.

The native CBOR parser requires exactly two unique byte-string entries (`signature`, `authenticatorData`), exactly 37 authenticator bytes, and no trailing data. The verifier computes `nonce = SHA256(authenticatorData || clientDataHash)` and passes nonce as **Data** to CryptoKit's message overload of `isValidSignature`, selecting ECDSA-SHA256 over nonce. The supplied known-valid vector covers this behavior.

## What VALID means

**VALID is a diagnostic result for the supplied inputs, not a complete server authentication decision.** The app checks the supplied key, signature, and requested comparisons. It does not establish Apple certificate-chain trust, key provenance, challenge freshness, or server-side replay protection. Additional assertion extension layouts are not supported. Attestation receipts are decoded using OpenSSL `-noverify` and are not presented as trusted evidence.

## Privacy and saved values

The app makes no network requests and includes no analytics. SwiftData saves drafts and the extracted public key on your Mac; the app does not add its own database encryption. **Clear** resets the active draft while preserving shared App ID. Clipboard contents and exported reports remain under your control. Reports are regenerated after reopening; changed inputs mark old reports stale.

Inputs are limited to 4 MB. Temporary attestation-processing files are removed after decoding. See [SECURITY.md](SECURITY.md) for scope and reporting guidance.

## Development

```sh
./script/build_and_run.sh          # Build debug app and launch
./script/build_and_run.sh --build  # Build only
./script/build_and_run.sh --package # Release ZIP + SHA256 checksum for this architecture
./script/test.sh                   # All regression and persistence checks
```

You can also open `Package.swift` in Xcode. The reproducible app-bundle entrypoint is the script above. Optional modes: `--debug`, `--logs`, and `--verify`.

Tests cover a synthetic known-valid assertion vector and negative cases, strict CBOR/DER handling, full receipt values, persistence across separate processes, draft independence, and clear behavior. GitHub Actions builds a release ZIP and runs tests on macOS.

The Python CLI remains available as `python3 appattest_decode.py --help`. Its canonical source is `Sources/AppAttestDecoder/Resources/appattest_decode.py`; the root file is a symlink so changes cannot drift between copies.

## AI-assisted development

Start any AI coding session with [AGENTS.md](AGENTS.md). It is the project handoff guide: the architecture, technology stack, setup and validation commands, assertion-verification contract, data-handling rules, and privacy/release guardrails needed to safely run and edit this repository without additional project context.

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). This is an independent project and is not affiliated with Apple.
