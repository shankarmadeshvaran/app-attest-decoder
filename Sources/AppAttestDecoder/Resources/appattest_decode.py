#!/usr/bin/env python3
"""Decode an Apple App Attest attestation object into readable text.

Input (first match wins): a command-line argument, --file, or the clipboard.
It accepts the raw hex, base64, or the whole "[AppAttest] [ATTESTATION_OBJECT_HEX] ..." log line.

    python3 appattest_decode.py                       # reads the clipboard
    python3 appattest_decode.py <hex-or-log-line>
    python3 appattest_decode.py --app-id TEAMID.com.example.app \
        --challenge example-challenge

Needs only the macOS system Python 3 and the `openssl` command line tool.
"""
import argparse
import base64
import hashlib
import os
import re
import struct
import subprocess
import sys
import tempfile

NONCE_OID = bytes.fromhex("06092a864886f763640802")  # 1.2.840.113635.100.8.2
RECEIPT_FIELDS = {
    2: "app id",
    3: "attested certificate",
    4: "client hash",
    5: "token",
    6: "receipt type",
    7: "environment",
    12: "creation time",
    21: "expiration time",
}
RECEIPT_TEXT_FIELDS = {2, 6, 7, 12, 21}


# ---------- minimal CBOR decoder ----------

def cbor_item(d, p, depth=0):
    if depth > 64:
        raise ValueError("CBOR nesting exceeds 64 levels")
    if p >= len(d):
        raise ValueError("unexpected end of CBOR data")
    ib = d[p]
    p += 1
    major, info = ib >> 5, ib & 0x1F
    if major == 7:
        if info == 20:
            return False, p
        if info == 21:
            return True, p
        if info in (22, 23):
            return None, p
        for code, fmt, size in ((25, ">e", 2), (26, ">f", 4), (27, ">d", 8)):
            if info == code:
                if p + size > len(d):
                    raise ValueError("truncated CBOR float")
                return struct.unpack(fmt, d[p:p + size])[0], p + size
        raise ValueError("unsupported CBOR simple value")
    if info < 24:
        arg = info
    else:
        sizes = {24: 1, 25: 2, 26: 4, 27: 8}
        if info not in sizes:
            raise ValueError("indefinite-length CBOR is not supported")
        if p + sizes[info] > len(d):
            raise ValueError("truncated CBOR length")
        arg = int.from_bytes(d[p:p + sizes[info]], "big")
        p += sizes[info]
    if major == 0:
        return arg, p
    if major == 1:
        return -1 - arg, p
    if major in (2, 3):
        if p + arg > len(d):
            raise ValueError("CBOR string runs past end of data")
        raw = bytes(d[p:p + arg])
        return (raw if major == 2 else raw.decode("utf-8")), p + arg
    if major == 4:
        items = []
        for _ in range(arg):
            value, p = cbor_item(d, p, depth + 1)
            items.append(value)
        return items, p
    if major == 5:
        result = {}
        for _ in range(arg):
            key, p = cbor_item(d, p, depth + 1)
            value, p = cbor_item(d, p, depth + 1)
            result[key] = value
        return result, p
    value, p = cbor_item(d, p)  # major 6: tag, keep the value
    return value, p


# ---------- minimal DER reader ----------

def der_read(d, p):
    if p + 2 > len(d):
        raise ValueError("truncated DER header")
    tag = d[p]
    length = d[p + 1]
    p += 2
    if length & 0x80:
        n = length & 0x7F
        if n == 0:
            raise ValueError("indefinite DER length")
        if p + n > len(d):
            raise ValueError("truncated DER length")
        length = int.from_bytes(d[p:p + n], "big")
        p += n
    if p + length > len(d):
        raise ValueError("truncated DER value")
    return tag, d[p:p + length], p + length


def der_children(content):
    out, p = [], 0
    while p < len(content):
        tag, value, p = der_read(content, p)
        out.append((tag, value))
    return out


# ---------- helpers ----------

def load_input(args):
    if args.hex:
        text = args.hex
    elif args.file:
        text = open(args.file).read()
    else:
        text = subprocess.run(["pbpaste"], capture_output=True, text=True).stdout
    match = re.search(r"(?:ATTESTATION_OBJECT_HEX|ASSERTION_OBJECT_HEX)\]?\s*([0-9a-fA-F]+)", text)
    if match:
        return bytes.fromhex(match.group(1))
    compact = re.sub(r"\s", "", text)
    if compact and re.fullmatch(r"[0-9a-fA-F]+", compact) and len(compact) % 2 == 0:
        return bytes.fromhex(compact)
    return base64.b64decode(compact, validate=True)


def openssl(args, data=None, suffix=".bin"):
    with tempfile.NamedTemporaryFile(suffix=suffix) as f:
        if data is not None:
            f.write(data)
            f.flush()
        return subprocess.run(["openssl"] + [f.name if a == "{f}" else a for a in args],
                              capture_output=True, text=True)


def describe_cert(der):
    result = openssl(["x509", "-inform", "der", "-in", "{f}", "-noout",
                      "-subject", "-issuer", "-serial", "-startdate", "-enddate"], der, ".der")
    return result.stdout.strip() if result.returncode == 0 else "(openssl could not read the certificate)"


def extract_nonce(cert):
    index = cert.find(NONCE_OID)
    if index < 0:
        return None
    try:
        _, octet, _ = der_read(cert, index + len(NONCE_OID))
        _, seq, _ = der_read(octet, 0)
        _, ctx, _ = der_read(seq, 0)
        _, nonce, _ = der_read(ctx, 0)
        return nonce
    except (IndexError, ValueError):
        return None


def parse_receipt(receipt):
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "receipt.der"), os.path.join(tmp, "payload.bin")
        open(src, "wb").write(receipt)
        subprocess.run(["openssl", "smime", "-verify", "-noverify", "-inform", "DER", "-in", src, "-out", dst],
                       capture_output=True)
        if not os.path.exists(dst) or os.path.getsize(dst) == 0:
            return None
        payload = open(dst, "rb").read()
    try:
        _, body, _ = der_read(payload, 0)
        fields = {}
        for _, seq in der_children(body):
            kids = der_children(seq)
            fields[int.from_bytes(kids[0][1], "big")] = kids[2][1]
        return fields
    except (IndexError, ValueError):
        return None


def section(title):
    print("\n== " + title + " " + "=" * max(0, 60 - len(title)))


def status(ok):
    return "OK" if ok else "MISMATCH"


# ---------- main ----------

def decode_assertion(raw, app_id=None):
    obj, end = cbor_item(raw, 0)
    if end != len(raw) or not isinstance(obj, dict):
        raise ValueError("expected one CBOR assertion map")
    auth = obj.get("authenticatorData")
    signature = obj.get("signature")
    if not isinstance(auth, bytes) or len(auth) < 37:
        raise ValueError("authenticatorData must contain at least 37 bytes")
    if not isinstance(signature, bytes) or not signature:
        raise ValueError("signature must be nonempty DER bytes")
    tag, content, signature_end = der_read(signature, 0)
    parts = der_children(content)
    if tag != 0x30 or signature_end != len(signature) or len(parts) != 2 or any(t != 2 or not v for t, v in parts):
        raise ValueError("signature must be a DER ECDSA sequence with r and s integers")
    section("Overview")
    print("object type:       assertion")
    print("authenticatorData (hex):", auth.hex())
    print("object size:      ", len(raw), "bytes")
    print("signature size:   ", len(signature), "bytes")
    section("authData")
    print("rpIdHash:         ", auth[:32].hex())
    print("flags:            ", hex(auth[32]))
    print("counter:          ", int.from_bytes(auth[33:37], "big"))
    if app_id:
        print("app id matches rpIdHash:    ", status(hashlib.sha256(app_id.encode()).digest() == auth[:32]))
    if len(auth) > 37:
        print("additional data:  ", auth[37:].hex())
    section("Signature")
    print("signature (hex):  ", signature.hex())
    print("signature (base64):", base64.b64encode(signature).decode())
    print("r:                ", parts[0][1].hex())
    print("s:                ", parts[1][1].hex())
    print("Signature verification is shown separately by the app when a public key and clientDataHash are provided.")
    print("Replay checking requires comparing the counter with the previous server-stored value.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("hex", nargs="?", help="attestation object as hex/base64, or the log line (default: clipboard)")
    parser.add_argument("--assertion", action="store_true", help="decode an App Attest assertion object")
    parser.add_argument("--file", help="read the input from a file")
    parser.add_argument("--app-id", help="TEAMID.bundle.id, checks it against rpIdHash")
    parser.add_argument("--challenge", help="challenge string sent to attestKey, checks it against the certificate nonce")
    args = parser.parse_args()

    raw = load_input(args)
    if args.assertion:
        decode_assertion(raw, args.app_id)
        return
    obj, end = cbor_item(raw, 0)
    if end != len(raw) or not isinstance(obj, dict):
        raise ValueError("expected one CBOR attestation map")
    auth = obj["authData"]
    att = obj["attStmt"]
    if obj.get("fmt") != "apple-appattest":
        raise ValueError("format must be apple-appattest")
    if not isinstance(auth, bytes) or len(auth) < 55 or not auth[32] & 0x40:
        raise ValueError("missing or truncated attested credential data")
    if not isinstance(att, dict):
        raise ValueError("attStmt must be a map")
    if not isinstance(att.get("x5c", []), list) or not all(isinstance(c, bytes) for c in att.get("x5c", [])):
        raise ValueError("x5c must be an array of certificates")
    if not isinstance(att.get("receipt", b""), bytes):
        raise ValueError("receipt must be bytes")

    section("Overview")
    print("format:           ", obj.get("fmt"))
    print("object size:      ", len(raw), "bytes")
    print("certificates:     ", len(att.get("x5c", [])))
    print("receipt size:     ", len(att.get("receipt", b"")), "bytes")

    section("authData")
    cred_len = int.from_bytes(auth[53:55], "big")
    cred_id = auth[55:55 + cred_len]
    if 55 + cred_len >= len(auth):
        raise ValueError("truncated credential ID or missing public key")
    cose, _ = cbor_item(auth, 55 + cred_len)
    if not isinstance(cose, dict):
        raise ValueError("credential public key must be a COSE map")
    print("rpIdHash:         ", auth[:32].hex())
    print("flags:            ", hex(auth[32]), "(attested credential data present)" if auth[32] & 0x40 else "")
    print("counter:          ", int.from_bytes(auth[33:37], "big"))
    print("environment:      ", auth[37:53].rstrip(b"\x00").decode("ascii", "replace"))
    print("key id (hex):     ", cred_id.hex())
    print("key id (base64):  ", base64.b64encode(cred_id).decode(), " <- same string stored in the Keychain")
    x, y = cose.get(-2), cose.get(-3)
    if x and y:
        print("public key x:     ", x.hex())
        print("public key y:     ", y.hex())
        point = b"\x04" + x + y
        print("key id = SHA256(public key):", status(hashlib.sha256(point).digest() == cred_id))
    if args.app_id:
        print("app id matches rpIdHash:    ", status(hashlib.sha256(args.app_id.encode()).digest() == auth[:32]))

    certs = att.get("x5c", [])
    for index, cert in enumerate(certs):
        section("Certificate %d (%s)" % (index, "leaf" if index == 0 else "intermediate"))
        print(describe_cert(cert))

    if certs:
        nonce = extract_nonce(certs[0])
        section("Nonce")
        print("nonce in leaf cert:", nonce.hex() if nonce else "(not found)")
        expected = hashlib.sha256(auth + hashlib.sha256(args.challenge.encode()).digest()).digest() if args.challenge else None
        if expected is not None:
            print("expected from challenge:", expected.hex())
            print("nonce matches challenge:", status(nonce == expected))
        else:
            print("(pass --challenge <string> to check it)")

    section("Receipt")
    fields = parse_receipt(att.get("receipt", b"")) if att.get("receipt") else None
    if fields is None:
        print("(could not parse the receipt)")
    else:
        for ftype in sorted(fields):
            name = RECEIPT_FIELDS.get(ftype, "type %d" % ftype)
            value = fields[ftype]
            shown = value.decode("utf-8", "replace") if ftype in RECEIPT_TEXT_FIELDS else value.hex()
            if ftype not in RECEIPT_TEXT_FIELDS:
                name += " (hex)"
            print("%-22s %s" % (name + ":", shown))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, IndexError, TypeError, AttributeError, RecursionError, struct.error, OSError) as error:
        sys.exit("Could not decode the input as an App Attest object: %s" % error)
