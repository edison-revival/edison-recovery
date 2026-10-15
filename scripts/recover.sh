#!/usr/bin/env bash
# Recover an Edison via the mask ROM DnX mode (USB 8086:e005) with xFSTK.
#
# Writes the IFWI (edison_ifwi-dbg-00.bin) and mainline U-Boot (u-boot-edison.img,
# which includes its environment) to the eMMC. Start this BEFORE resetting the board:
# the DnX window is under a second per boot.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

"$root/scripts/fetch-blobs.sh"

if [ ! -f out/uboot/u-boot-edison.img ]; then
    echo "out/uboot/u-boot-edison.img not found; run scripts/build.sh first" >&2
    exit 1
fi
(cd out/uboot && sha256sum -c --quiet SHA256SUMS)

if ! docker image inspect edison-recovery/xfstk >/dev/null 2>&1; then
    echo "edison-recovery/xfstk image not found; run scripts/build.sh first" >&2
    exit 1
fi

mkdir -p logs
log="logs/recover-$(date +%Y%m%d-%H%M%S).log"

cat <<EOF

About to write the IFWI and U-Boot $(cat out/uboot/VERSION) to the Edison's eMMC.
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
    -v "$root/out/uboot:/uboot:ro" \
    edison-recovery/xfstk \
    --gpflags 0x80000007 \
    --osimage /uboot/u-boot-edison.img \
    --fwdnx /blobs/edison_dnx_fwr.bin \
    --fwimage /blobs/edison_ifwi-dbg-00.bin \
    --osdnx /blobs/edison_dnx_osr.bin \
    2>&1 | tee "$log"
