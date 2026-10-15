"""Tests for scripts/mkosip.py. Standard library only: python -m unittest discover tests"""

import hashlib
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import mkosip  # noqa: E402

# SHA256 of the header produced by meta-intel-edison's u-boot-osip.inc with its default
# values (commit 250cb13241f1ee0438e9717b06200f1467972d68). The same header is in
# edison-fw's released u-boot-edison.img, and it booted mainline U-Boot on hardware.
REFERENCE_SHA256 = "097ddb4108cf271a3ae2f21451bd6ebcb73be879c47f44d68a796ed30df45a28"


class OsipHeaderTests(unittest.TestCase):
    def setUp(self):
        self.hdr = mkosip.osip_header()

    def test_matches_known_good_header(self):
        self.assertEqual(hashlib.sha256(self.hdr).hexdigest(), REFERENCE_SHA256)

    def test_size_and_signatures(self):
        self.assertEqual(len(self.hdr), 512)
        self.assertEqual(self.hdr[:4], b"$OS$")
        self.assertEqual(self.hdr[0x1FE:], b"\x55\xaa")

    def test_checksum(self):
        # XOR of the header and the one OSII, including the checksum byte, is zero.
        acc = 0
        for b in self.hdr[:0x38]:
            acc ^= b
        self.assertEqual(acc, 0)

    def test_os_image_descriptor(self):
        lba, load, entry, blocks = struct.unpack_from("<IIII", self.hdr, 0x24)
        self.assertEqual(lba, 2048)  # u-boot0, 1 MiB into the eMMC
        self.assertEqual(entry - load, 0x1000)  # past U-Boot's 4 KiB prefix
        self.assertEqual(entry, 0x01101000)  # U-Boot's CONFIG_TEXT_BASE
        self.assertEqual(blocks * 512, 6 * 1024 * 1024)

    def test_protective_mbr_entry(self):
        self.assertEqual(self.hdr[0x1C2], 0xEE)

    def test_writes_file(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "edison-osip.dat"
            mkosip.main(["mkosip.py", str(out)])
            self.assertEqual(out.read_bytes(), self.hdr)

    def test_usage_without_output_path(self):
        with self.assertRaises(SystemExit):
            mkosip.main(["mkosip.py"])


if __name__ == "__main__":
    unittest.main()
