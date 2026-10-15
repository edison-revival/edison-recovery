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

Expected: xFSTK reports the device found and the downloads completing. The board resets,
and about 10 seconds later the serial console shows the mainline U-Boot banner.

## What it writes

- **IFWI** `edison_ifwi-dbg-00.bin` to the eMMC boot partitions.
- **U-Boot** `u-boot-edison.img` (OSIP header, U-Boot and its default environment).

The rest of the eMMC (including the `factory` partition) isn't touched.

## What's in here

| Path | Purpose |
|---|---|
| `docker/xfstk.Dockerfile` | Builds `xfstk-dldr-solo` from [edison-fw/xFSTK](https://github.com/edison-fw/xFSTK) v1.8.6 (pinned commit) on Ubuntu 24.04 |
| `patches/` | Patches applied to xFSTK: 10 ms device polling and a longer timeout, so the sub-second DnX window isn't missed |
| `docker/uboot.Dockerfile` | Builds mainline U-Boot v2026.10 `edison_defconfig` (pinned commit); checks the 4 KiB zero prefix |
| `blobs.lock` | URLs and SHA256 checksums of the Intel DnX/IFWI blobs |
| `scripts/fetch-blobs.sh` | Downloads the blobs into `blobs/` and refuses to continue on a mismatch |
| `scripts/build.sh`, `scripts/recover.sh` | Build, then recover |

## Blobs and licences

The Intel IFWI and DnX images are **not** in this repo: no licence covering their
redistribution has been found. `fetch-blobs.sh` downloads them from the
`edison-fw/meta-intel-edison` repo at a pinned commit and verifies their checksums. The
same checksums match the independent `iot-alex/edison-src` mirror.

xFSTK is LGPL-2.1 and is built from source; no binaries are distributed.

## Known pitfalls

- **U-Boot v2026.04 is broken for Edison**: the image lacks its 4 KiB prefix and the board
  stays in DnX. This repo pins v2026.10.
- Stock xFSTK polls once a second for ~21 s and usually misses the DnX window. Use the
  patched build here.
- If nothing is detected at all, reseat or swap the USB cable before anything else.
