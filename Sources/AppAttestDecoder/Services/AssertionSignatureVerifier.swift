import Foundation
import CryptoKit

enum AssertionSignatureVerifier {
    static func hex(_ data: some Sequence<UInt8>) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func hexBytes(_ text: String, input: String) throws -> Data {
        var value = text.filter { !$0.isWhitespace }
        if value.hasPrefix("0x") || value.hasPrefix("0X") { value = String(value.dropFirst(2)) }
        guard !value.isEmpty, value.count.isMultiple(of: 2), value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw DecoderFailure.message("\(input): expected complete hexadecimal bytes.")
        }
        var result = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let end = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<end], radix: 16) else { throw DecoderFailure.message("\(input): invalid hex.") }
            result.append(byte)
            index = end
        }
        return result
    }

    static func assertionBytes(_ text: String) throws -> Data {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = try? hexBytes(value, input: "CBOR") { return data }
        guard let data = Data(base64Encoded: value.filter { !$0.isWhitespace }) else {
            throw DecoderFailure.message("CBOR: assertion must be hex or Base64.")
        }
        return data
    }

    static func report(assertion: String, publicKey: String, options: AssertionVerificationInputs, appID: String) throws -> String {
        let raw = try assertionBytes(assertion)
        let object = try AssertionCBOR(data: raw)
        let auth = object.authenticatorData
        let rpID = Data(auth.prefix(32))
        let counter = auth.suffix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        var lines = ["\n== Overview ==================================================",
                     "object type: assertion", "object size: \(raw.count) bytes",
                     "\n== authData ==================================================",
                     "rpIdHash: \(hex(rpID))", "flags: 0x\(String(auth[32], radix: 16))", "counter: \(counter)"]
        if !appID.isEmpty {
            lines.append("app id matches rpIdHash: \(Data(SHA256.hash(data: Data(appID.utf8))) == rpID ? "OK" : "MISMATCH")")
        }
        var counterOK = true
        if !options.previousCounter.isEmpty {
            guard let previous = UInt32(options.previousCounter.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw DecoderFailure.message("Previous counter: enter an unsigned 32-bit integer.")
            }
            counterOK = counter > previous
            lines += ["previous counter: \(previous)", "counter increased: \(counterOK ? "OK" : "MISMATCH")"]
        }
        lines += ["\n== Signature =================================================", "signature (hex): \(hex(object.signature))"]
        let signature: P256.Signing.ECDSASignature
        do { signature = try P256.Signing.ECDSASignature(derRepresentation: object.signature) }
        catch { throw DecoderFailure.message("Signature DER: expected a DER-encoded P-256 ECDSA signature (not the whole CBOR assertion).") }
        lines.append("\n== Signature verification ====================================")
        do {
            let point: Data
            let hasCoordinates = !options.publicKeyX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !options.publicKeyY.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasCoordinates {
                let x = try hexBytes(options.publicKeyX, input: "Public key x")
                let y = try hexBytes(options.publicKeyY, input: "Public key y")
                guard x.count == 32, y.count == 32 else { throw DecoderFailure.message("Public key: x and y must each be 32 bytes.") }
                point = Data([4]) + x + y
                lines.append("public key source: 04 || x || y")
            } else {
                guard !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return (lines + ["keyId check: NOT CHECKED", "Signature verification not performed. Enter the attested public key."]).joined(separator: "\n")
                }
                point = try hexBytes(publicKey, input: "Public key")
            }
            guard point.count != 32 else {
                throw DecoderFailure.message("Public key: this is a 32-byte hash, possibly the Key ID. Use the 65-byte 04 || x || y point from attestation.")
            }
            guard point.count == 65, point.first == 4 else {
                throw DecoderFailure.message("Public key: expected 65-byte X9.63 point starting with 04, or separate 32-byte x and y.")
            }
            let key: P256.Signing.PublicKey
            do { key = try P256.Signing.PublicKey(x963Representation: point) }
            catch { throw DecoderFailure.message("Public key: the point is not valid on the P-256 curve.") }
            let derivedID = Data(SHA256.hash(data: point)).base64EncodedString()
            lines.append("derived keyId: \(derivedID)")
            guard !options.keyID.isEmpty else {
                return (lines + ["keyId check: NOT CHECKED", "Signature verification not performed. Enter the Base64 Key ID for the sanity check."]).joined(separator: "\n")
            }
            guard let keyID = Data(base64Encoded: options.keyID.trimmingCharacters(in: .whitespacesAndNewlines)), keyID.count == 32 else {
                throw DecoderFailure.message("Key ID: expected Base64 of a 32-byte SHA-256 hash.")
            }
            guard keyID == Data(SHA256.hash(data: point)) else {
                return (lines + ["keyId check: MISMATCH", "public key does not match Key ID", "result: INVALID"]).joined(separator: "\n")
            }
            lines.append("keyId check: OK")
            let clientHash: Data
            if options.useHash {
                guard options.clientDataHash.count == 64 else { throw DecoderFailure.message("clientDataHash: expected exactly 64 hex characters.") }
                clientHash = try hexBytes(options.clientDataHash, input: "clientDataHash")
            } else {
                let fields = options.clientData.components(separatedBy: "\n")
                guard fields.count == 5, !options.clientData.contains("\r"), fields.allSatisfy({ !$0.isEmpty }),
                      fields[2].count == 64, fields[2].utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                    throw DecoderFailure.message("clientData: enter exactly five LF-separated lines: METHOD, path[?query], lowercase hex SHA256(body), timestamp, nonce. No trailing newline.")
                }
                clientHash = Data(SHA256.hash(data: Data(options.clientData.utf8)))
            }
            let nonce = Data(SHA256.hash(data: auth + clientHash))
            // Data selects CryptoKit's message overload: ECDSA-SHA256 over the nonce.
            let valid = key.isValidSignature(signature, for: nonce)
            let appOK = appID.isEmpty || Data(SHA256.hash(data: Data(appID.utf8))) == rpID
            lines += ["clientDataHash: \(hex(clientHash))", "nonce: \(hex(nonce))",
                      "signature verifies: \(valid ? "OK" : "MISMATCH")",
                      "result: \(valid && appOK && counterOK ? "VALID" : "INVALID")",
                      "VALID covers the supplied key, signature and requested comparisons; key trust and challenge freshness require server validation."]
        } catch {
            lines += ["verification unavailable: \(error.localizedDescription)", "result: INVALID"]
        }
        return lines.joined(separator: "\n")
    }
}
