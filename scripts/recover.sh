#!/usr/bin/env bash
# Recover an Edison via the mask ROM DnX mode (USB 8086:e005) with xFSTK.
#
# Writes the IFWI (edison_ifwi-dbg-00.bin) and mainline U-Boot (u-boot-edison.img,
# which includes its environment) to the eMMC. Start this BEFORE resetting the board:
# the DnX window is under a second per boot.
#
# Usage: scripts/recover.sh [--uboot DIR] [xfstk-dldr-solo options]
#   --uboot DIR  U-Boot files from a release download (u-boot-edison.img, VERSION,
#                SHA256SUMS) instead of the local build in out/uboot.
# Other arguments are passed to xfstk-dldr-solo, e.g. -v: xFSTK exits silently on a
# protocol error unless -v is given.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

uboot="$root/out/uboot"
if [ "${1:-}" = --uboot ]; then
    uboot="$(cd "${2:?--uboot needs a directory}" && pwd)"
    shift 2
fi

"$root/scripts/fetch-blobs.sh"

if [ ! -f "$uboot/u-boot-edison.img" ]; then
    echo "$uboot/u-boot-edison.img not found: run scripts/build.sh, or download the" >&2
    echo "U-Boot files from a release and pass --uboot DIR" >&2
    exit 1
fi
(cd "$uboot" && sha256sum -c --quiet --ignore-missing SHA256SUMS)

if ! docker image inspect edison-recovery/xfstk >/dev/null 2>&1; then
    echo "edison-recovery/xfstk image not found; run scripts/build.sh xfstk first" >&2
    exit 1
fi

mkdir -p logs
log="logs/recover-$(date +%Y%m%d-%H%M%S).log"

cat <<EOF

About to write the IFWI and U-Boot $(cat "$uboot/VERSION") to the Edison's eMMC.
  1. Edison J16 (USB OTG) connected to this machine, SW1 towards the micro-USB ports.
  2. Serial console on J3 open and logging, if you can.
  3. When xFSTK says it's waiting, power-cycle or reset the board.
     (A board with no bootloader also resets itself every 1-2 minutes.)
Log: $log

EOF
read -r -p "Continue? [y/N] " answer
[ "$answer" = y ] || [ "$answer" = Y ] || exit 1

# --privileged and the /dev/bus/usb bind mount let the container see the DnX device
# when it appears; it doesn't exist yet when the container starts. -t keeps xFSTK's
# output line-buffered through tee.
docker run --rm -t --privileged \
    -e XFSTK_DETECT_TIMEOUT_S="${XFSTK_DETECT_TIMEOUT_S:-300}" \
    -v /dev/bus/usb:/dev/bus/usb \
    -v "$root/blobs:/blobs:ro" \
    -v "$uboot:/uboot:ro" \
    edison-recovery/xfstk \
    --gpflags 0x80000007 \
    --osimage /uboot/u-boot-edison.img \
    --fwdnx /blobs/edison_dnx_fwr.bin \
    --fwimage /blobs/edison_ifwi-dbg-00.bin \
    --osdnx /blobs/edison_dnx_osr.bin \
    "$@" \
    2>&1 | tee "$log"
