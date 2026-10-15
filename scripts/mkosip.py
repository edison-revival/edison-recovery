#!/usr/bin/env python3
"""Write the 512-byte OSIP header for an Edison xFSTK image (u-boot-edison.img).

Mainline U-Boot's board/intel/edison/edison-osip.dat has been an empty file since it
was added (2e3b88301400, 2020), so binman builds u-boot-edison.img with 512 zero bytes
where the OSIP header belongs, and the OS DnX stops responding after receiving it.

The values match meta-intel-edison's u-boot-osip.inc (MIT), which is what the community
has used for years: one OS image (U-Boot) at eMMC LBA 2048, loaded to 0x01100000 and
entered at 0x01101000 (past U-Boot's 4 KiB zero prefix), 6 MiB long. The sector doubles
as a protective MBR for the GPT that follows.

Usage: mkosip.py OUTPUT
"""

import struct
import sys

OS_IMAGE_LBA = 2048  # u-boot0 partition, 1 MiB into the eMMC
DDR_LOAD_ADDRESS = 0x01100000
ENTRY_POINT = 0x01101000  # load address + 4 KiB prefix
OS_IMAGE_BLOCKS = 6 * 1024 * 1024 // 512
OS_IMAGE_ATTRIBUTE = 0x0F

HEADER_SIZE = 0x20
OSII_SIZE = 0x18


def osip_header():
    hdr = bytearray(b"\xff" * 512)

    # Header (0x00-0x1f)
    hdr[0x00:0x20] = struct.pack(
        "<4sBBBBBBH20s",
        b"$OS$",
        0,  # reserved
        0,  # header minor revision
        1,  # header major revision
        0,  # checksum, filled in below
        1,  # number of pointers
        1,  # number of images
        HEADER_SIZE + OSII_SIZE,  # header size
        bytes(20),  # reserved
    )

    # First OS image identifier (OSII, 0x20-0x37)
    hdr[0x20:0x38] = struct.pack(
        "<HHIIIIB3s",
        0,  # OS revision minor
        0,  # OS revision major
        OS_IMAGE_LBA,
        DDR_LOAD_ADDRESS,
        ENTRY_POINT,
        OS_IMAGE_BLOCKS,
        OS_IMAGE_ATTRIBUTE,
        bytes(3),
    )

    # MBR tail (0x1b8-0x1ff): disk signature, null, one protective GPT partition, 0x55aa
    hdr[0x1B8:0x1BE] = bytes(6)
    hdr[0x1BE:0x1CE] = struct.pack(
        "<B3sB3sII",
        0,  # not bootable
        bytes(3),  # CHS start
        0xEE,  # GPT protective
        bytes(3),  # CHS end
        1,  # first LBA
        0x03A3E000,  # sector count (as in meta-intel-edison)
    )
    hdr[0x1CE:0x1FE] = bytes(48)
    hdr[0x1FE:0x200] = b"\x55\xaa"

    # XOR checksum over the header and the one OSII
    checksum = 0
    for b in hdr[: HEADER_SIZE + OSII_SIZE]:
        checksum ^= b
    hdr[0x07] = checksum
    return bytes(hdr)


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    with open(argv[1], "wb") as f:
        f.write(osip_header())


if __name__ == "__main__":
    main(sys.argv)
