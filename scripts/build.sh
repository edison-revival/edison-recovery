#!/usr/bin/env bash
# Build the xFSTK container image and mainline U-Boot (into out/uboot/).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

docker build -t edison-recovery/xfstk -f docker/xfstk.Dockerfile .
docker build --output out/uboot -f docker/uboot.Dockerfile .

echo
echo "U-Boot $(cat out/uboot/VERSION):"
(cd out/uboot && sha256sum -c SHA256SUMS)
