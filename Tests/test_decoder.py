import base64
import hashlib
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def cbor(value):
    def head(major, n):
        if n < 24:
            return bytes([major * 32 + n])
        return bytes([major * 32 + 24, n])
    if isinstance(value, bytes):
        return head(2, len(value)) + value
    if isinstance(value, str):
        return head(3, len(value)) + value.encode()
    if isinstance(value, dict):
        return head(5, len(value)) + b''.join(cbor(k) + cbor(v) for k, v in value.items())
    if isinstance(value, list):
        return head(4, len(value)) + b''.join(cbor(v) for v in value)
    return head(0, value) if value >= 0 else head(1, -1 - value)


class DecoderTests(unittest.TestCase):
    def fixture(self):
        x, y = bytes(range(32)), bytes(range(32, 64))
        key = hashlib.sha256(b'\x04' + x + y).digest()
        auth = hashlib.sha256(b'TEAM.example.app').digest() + b'\x40' + bytes(4)
        auth += b'appattestdevelop' + b'\x00\x20' + key + cbor({-2: x, -3: y})
        return cbor({'fmt': 'apple-appattest', 'authData': auth, 'attStmt': {'x5c': []}})

    def run_decoder(self, text, *args):
        return subprocess.run(['/usr/bin/python3', str(ROOT / 'appattest_decode.py'), text, *args], capture_output=True, text=True)

    def test_encodings_and_checks(self):
        raw = self.fixture()
        for text in [raw.hex(), base64.b64encode(raw).decode()]:
            result = self.run_decoder(text, '--app-id', 'TEAM.example.app')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('key id = SHA256(public key): OK', result.stdout)
            self.assertIn('app id matches rpIdHash:     OK', result.stdout)
        self.assertIn('MISMATCH', self.run_decoder(raw.hex(), '--app-id', 'wrong').stdout)

    def test_malformed(self):
        for text in ['', 'invalid!', 'a0', '5810ff', ('81' * 100) + '00', self.fixture().hex() + '00']:
            result = self.run_decoder(text)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('Traceback', result.stderr)

    def test_assertion(self):
        auth = hashlib.sha256(b'TEAM.example.app').digest() + b'\x00' + (42).to_bytes(4, 'big')
        raw = cbor({'authenticatorData': auth, 'signature': bytes.fromhex('3006020101020102')})
        for text in [raw.hex(), base64.b64encode(raw).decode()]:
            result = self.run_decoder(text, '--assertion', '--app-id', 'TEAM.example.app')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('counter:           42', result.stdout)
            self.assertIn('app id matches rpIdHash:     OK', result.stdout)
            self.assertIn('Signature verification is shown separately', result.stdout)
        self.assertIn('MISMATCH', self.run_decoder(raw.hex(), '--assertion', '--app-id', 'wrong').stdout)
        for obj in [{}, {'authenticatorData': auth[:36], 'signature': b'bad'},
                    {'authenticatorData': auth, 'signature': b'bad'}]:
            result = self.run_decoder(cbor(obj).hex(), '--assertion')
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('Traceback', result.stderr)

    def test_receipt_values_are_complete(self):
        import contextlib
        import importlib.util
        import io
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('decoder', ROOT / 'appattest_decode.py')
        decoder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(decoder)
        obj, _ = decoder.cbor_item(self.fixture(), 0)
        obj['attStmt']['receipt'] = b'placeholder'
        fields = {3: bytes(range(256)) * 5, 4: bytes(range(32)), 5: b'full-token-value' * 20}
        output = io.StringIO()
        with patch('sys.argv', ['decoder', cbor(obj).hex()]), patch.object(decoder, 'parse_receipt', return_value=fields), contextlib.redirect_stdout(output):
            decoder.main()
        report = output.getvalue()
        for value in fields.values():
            self.assertIn(value.hex(), report)
        self.assertIn('attested certificate (hex):', report)
        self.assertNotIn('...', report)

    def test_resource_matches_source(self):
        self.assertEqual((ROOT / 'appattest_decode.py').read_bytes(), (ROOT / 'Sources/AppAttestDecoder/Resources/appattest_decode.py').read_bytes())


if __name__ == '__main__':
    unittest.main()
