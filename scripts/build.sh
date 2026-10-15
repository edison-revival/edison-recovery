#!/usr/bin/env bash
# Build the xFSTK container image and mainline U-Boot (into out/uboot/).
# Usage: scripts/build.sh [xfstk|uboot|all]   (default: all)
# With U-Boot from a release download, only `scripts/build.sh xfstk` is needed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
what="${1:-all}"
cd "$root"

if [ "$what" = xfstk ] || [ "$what" = all ]; then
    docker build -t edison-recovery/xfstk -f docker/xfstk.Dockerfile .
fi

if [ "$what" = uboot ] || [ "$what" = all ]; then
    docker build --output out/uboot -f docker/uboot.Dockerfile .
    echo
    echo "U-Boot $(cat out/uboot/VERSION):"
    (cd out/uboot && sha256sum -c SHA256SUMS)
fi
