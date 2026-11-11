import Foundation

struct AssertionCBOR {
    let signature: Data
    let authenticatorData: Data

    init(data: Data) throws {
        var reader = Reader(bytes: Array(data))
        guard try reader.header(expectedMajor: 5) == 2 else { throw DecoderFailure.message("CBOR: assertion must be a map with exactly two entries.") }
        var fields: [String: Data] = [:]
        for _ in 0..<2 {
            let keyData = try reader.payload(major: 3)
            guard let key = String(data: keyData, encoding: .utf8),
                  ["signature", "authenticatorData"].contains(key), fields[key] == nil else {
                throw DecoderFailure.message("CBOR: expected unique signature and authenticatorData keys.")
            }
            fields[key] = try reader.payload(major: 2)
        }
        guard reader.index == reader.bytes.count, let signature = fields["signature"],
              let auth = fields["authenticatorData"], auth.count == 37 else {
            throw DecoderFailure.message("CBOR: authenticatorData must be exactly 37 bytes, with no trailing CBOR data.")
        }
        self.signature = signature
        authenticatorData = auth
    }

    private struct Reader {
        let bytes: [UInt8]
        var index = 0
        mutating func byte() throws -> UInt8 {
            guard index < bytes.count else { throw DecoderFailure.message("CBOR: unexpected end of input.") }
            defer { index += 1 }
            return bytes[index]
        }
        mutating func header(expectedMajor: UInt8) throws -> Int {
            let first = try byte()
            guard first >> 5 == expectedMajor else { throw DecoderFailure.message("CBOR: incorrect value type.") }
            let info = first & 31
            if info < 24 { return Int(info) }
            let width: Int
            switch info {
            case 24: width = 1
            case 25: width = 2
            case 26: width = 4
            case 27: width = 8
            default: throw DecoderFailure.message("CBOR: indefinite lengths are unsupported.")
            }
            var result: UInt64 = 0
            for _ in 0..<width { result = result << 8 | UInt64(try byte()) }
            guard result <= UInt64(bytes.count) else { throw DecoderFailure.message("CBOR: length exceeds input size.") }
            return Int(result)
        }
        mutating func payload(major: UInt8) throws -> Data {
            let length = try header(expectedMajor: major)
            guard length <= bytes.count - index else { throw DecoderFailure.message("CBOR: truncated string.") }
            defer { index += length }
            return Data(bytes[index..<index + length])
        }
    }
}
