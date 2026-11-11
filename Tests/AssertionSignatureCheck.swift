import Foundation
import CryptoKit

enum DecoderFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

@main
struct SignatureCheck {
    static func main() throws {
        func expect(_ value: Bool) { assert(value) }
        let x = "ef7bd7b47b9d02323d608807cd68418629bcb1cf41df13f1a05b1d8a153d136a"
        let y = "08f72886004f1abbdad7ee1f76bf90fc9b5a49e077ef70f4a13d1f0126ca96f6"
        let point = "04" + x + y
        let assertion = "a2697369676e617475726558483046022100a8e2890d2ada2d852ee83325cfe359070aa496f1306a11bef73df5f37010e922022100cb3b92c198c1553aac658e85b251968c61328965e7e30dd7804b75a38b26398a7161757468656e74696361746f72446174615825bd26f9676eafca2773715b56168b923935cf63d9829da99fa8915a81edc201584000000001"
        var options = AssertionVerificationInputs()
        options.keyID = "dfYxxv+MXN5OLYUUxSy8LZPD+hNYgU75JQBTCX40//4="
        options.clientData = "POST\n/example/verify\n41b174fe54481caaf66c1d44443215946d75a54903795fbb9948dc479f92c9f1\n1700000000\n00000000-0000-4000-8000-000000000001"
        let expectedHash = "3800ee016bc6ba2c6e7ccb1aaa5eca0f958bc7ee014ee965ee55b64685ffaa63"
        func report(_ value: AssertionVerificationInputs, key: String = point, blob: String = assertion, app: String = "") throws -> String {
            try AssertionSignatureVerifier.report(assertion: blob, publicKey: key, options: value, appID: app)
        }
        let valid = try report(options)
        assert(valid.contains("result: VALID"), valid)
        assert(valid.contains("counter: 1"))
        assert(valid.contains("flags: 0x40"))
        assert(valid.contains("clientDataHash: " + expectedHash))
        assert(valid.contains("rpIdHash: bd26f9676eafca2773715b56168b923935cf63d9829da99fa8915a81edc20158"))
        print(valid)
        let withNewline = options.clientData + "\n"
        var invalidData = options
        invalidData.clientData = withNewline
        expect(try report(invalidData).contains("clientData:"))
        expect(try report(options, app: "wrong.app").contains("result: INVALID"))
        let malformedDER = assertion.replacingOccurrences(of: "30460221", with: "31460221")
        do { _ = try report(options, blob: malformedDER); fatalError("Expected signature DER error") }
        catch { assert(error.localizedDescription.contains("Signature DER")) }
        options.useCoordinates = true; options.publicKeyX = x; options.publicKeyY = y
        expect(try report(options).contains("result: VALID"))
        options.useCoordinates = false
        expect(try report(options, key: "").contains("result: VALID"))
        options.useHash = true; options.clientDataHash = expectedHash
        expect(try report(options).contains("result: VALID"))
        let raw = try AssertionSignatureVerifier.assertionBytes(assertion)
        expect(try report(options, blob: raw.base64EncodedString()).contains("result: VALID"))
        options.clientDataHash = String(repeating: "0", count: 64)
        expect(try report(options).contains("signature verifies: MISMATCH"))
        options.clientDataHash = expectedHash
        options.previousCounter = "1"
        expect(try report(options).contains("result: INVALID"))
        options.previousCounter = "0"
        expect(try report(options).contains("result: VALID"))
        options.keyID = Data(repeating: 0, count: 32).base64EncodedString()
        let mismatch = try report(options)
        assert(mismatch.contains("public key does not match Key ID"))
        assert(!mismatch.contains("signature verifies:"))
        options.useCoordinates = false
        options.publicKeyX = ""; options.publicKeyY = ""
        expect(try report(options, key: String(repeating: "0", count: 64)).contains("possibly the Key ID"))
        for blob in ["a0", assertion + "00", "a2697369676e6174757265017161757468656e74696361746f72446174615825" + String(repeating: "00", count: 37)] {
            do { _ = try report(options, blob: blob); fatalError("Expected CBOR error") }
            catch { assert(error.localizedDescription.contains("CBOR")) }
        }
        print("Vector VALID, counter 1; negative and input checks passed")
    }
}
