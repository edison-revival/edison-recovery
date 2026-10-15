# edison-recovery

Recover a bricked Intel Edison through its mask ROM download mode (DnX, USB `8086:e005`)
with xFSTK, installing the IFWI and mainline U-Boot.

Use this when the serial console stops at `*** Ready to receive application ***` and no
U-Boot banner follows (see `edison-docs/runbooks/stage0-diagnose.md`).

## Requirements

- A Linux x86_64 host with Docker. Tested on Linux Mint 22.3 (Ubuntu 24.04 base).
  Run it natively: the DnX window is under a second, too short for manual USB passthrough
  into WSL2 or most VMs.
- Your user in the `docker` group.
- A micro-USB **data** cable to the Edison's J16 (OTG) port, SW1 towards the micro-USB ports.
- Ideally a second cable on J3 for the serial console (115200 8N1).

## Usage

Clone this repo (or download a [release](https://github.com/edison-revival/edison-recovery/releases)'s
source), then either:

- **With a release's prebuilt U-Boot** (download `u-boot-edison.img`, `VERSION` and
  `SHA256SUMS` from the release into a folder):

  ```
  scripts/build.sh xfstk
  ```

  ```
  scripts/recover.sh --uboot path/to/that/folder
  ```

- **Building everything yourself:**

  ```
  scripts/build.sh
  ```

  ```
  scripts/recover.sh
  ```

`build.sh` builds the xFSTK container image and mainline U-Boot (`out/uboot/`).
`recover.sh` downloads and verifies the Intel blobs, then starts xFSTK waiting for the
board. Reset or power-cycle the Edison once it says it's waiting. A board with no
bootloader also resets itself every 1–2 minutes, so waiting works too (default timeout
300 s, override with `XFSTK_DETECT_TIMEOUT_S`).

Expected: xFSTK ends with `Firmware and OS download completed.` The board resets, and
about 10 seconds later the serial console shows the `U-Boot 2026.10` banner. With no kernel
installed yet, U-Boot then fails to boot and resets in a loop, opening a short DFU window
(`8087:0a99`) each time. That's expected: next, flash an OS with
[edison-image](https://github.com/edison-revival/edison-image)'s `flash.py`, which
catches that window.

## What it writes

- **IFWI** `edison_ifwi-dbg-00.bin` to the eMMC boot partitions.
- **U-Boot** `u-boot-edison.img` (OSIP header, U-Boot and its default environment).

On its first boot, U-Boot's default environment also **rewrites the GPT** (`Partitioning
using GPT`) with the standard Edison layout and fresh partition UUIDs. The layout is the same
as the vendor one, and partition contents (including `factory`) aren't erased, but anything
that referred to the old partition UUIDs won't find them.

The first boot after recovery may hang in the automatic 3-second DFU window without
appearing on USB. Reset the board once; later boots behave normally.

## Blobs and licences

The Intel IFWI and DnX images are **not** in this repo: no licence covering their
redistribution has been found. `fetch-blobs.sh` downloads them from the
`edison-fw/meta-intel-edison` repo at a pinned commit and verifies their checksums. The
same checksums match the independent `iot-alex/edison-src` mirror.

xFSTK is LGPL-2.1 and is built from source; no binaries are distributed.

## Licence

Our own code is under the MIT licence (`LICENSE`). Exceptions:
- `patches/xfstk-*.patch` modify xFSTK and are LGPL-2.1, like xFSTK.
- `scripts/mkosip.py` is our code; the OSIP values it writes match meta-intel-edison's
  `u-boot-osip.inc` (MIT).
- U-Boot, built by `docker/uboot.Dockerfile`, is GPL-2.0.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the repo layout, tests, releasing and
conventions.

## Known pitfalls

- **Mainline U-Boot's `u-boot-edison.img` can't be used with xFSTK as built.** Its OSIP
  header file (`board/intel/edison/edison-osip.dat`) has been empty since 2020, and binman
  places U-Boot without its 4 KiB prefix. `docker/uboot.Dockerfile` generates the header
  (`scripts/mkosip.py`) and fixes the layout. Symptom with the stock image: xFSTK fails after
  "sending OSIP header" with `Error Code: 4`, and logs `_num OS Images : 0`.
- **U-Boot v2026.04 is broken for Edison**: the image lacks its 4 KiB prefix and the board
  stays in DnX. This repo pins v2026.10.
- xFSTK exits silently on protocol errors. Run `scripts/recover.sh -v` to see why.
- Stock xFSTK polls once a second for ~21 s and usually misses the DnX window. Use the
  patched build here.
- If nothing is detected at all, reseat or swap the USB cable before anything else.
