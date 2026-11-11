# Security and scope

This is a local developer diagnostic tool, not a production authentication service.
A VALID assertion means its signature and the requested comparisons passed for the
inputs supplied. It does not establish certificate-chain trust, key provenance,
challenge freshness, or a server's replay protection. Attestation certificate trust
and receipt trust are not fully validated; receipt extraction uses OpenSSL -noverify.
The app supports the documented 37-byte assertion authenticator layout, not additional
extension data.

The app makes no network requests and does not contain analytics. SwiftData saves
entered values locally and unencrypted by the app; protection depends on macOS and
your account/disk security. Clipboard and exported reports are under your control.
Do not paste private keys; verification only needs a public key.

Do not report vulnerabilities with real customer data or secrets in public issues.
Use the repository's private vulnerability-reporting feature if enabled. Otherwise
open an issue asking for a private reporting channel without including exploit details.

Builds use ad-hoc local signing. No Developer ID or notarization is claimed. The
installer does not modify Gatekeeper, remove quarantine, or disable system protections.
