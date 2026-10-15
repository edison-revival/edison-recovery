# Mainline U-Boot edison_defconfig, pinned to an exact commit and base image.
# Build with: docker build --output out/uboot -f docker/uboot.Dockerfile .
ARG BASE=ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

FROM ${BASE} AS build
# U-Boot tag v2026.10. Never use v2026.04: it drops the 4 KiB prefix and the board
# stays in DnX (fixed upstream in 895d3c67cd).
ARG UBOOT_COMMIT=5508406582f6f7120dce0c4b3059819a41788db2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git gcc make bison flex bc \
      libssl-dev libgnutls28-dev uuid-dev \
      python3 python3-dev python3-setuptools python3-pyelftools python3-libfdt \
      swig device-tree-compiler acpica-tools \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --filter=blob:none https://github.com/u-boot/u-boot.git /src \
 && git -C /src checkout --detach ${UBOOT_COMMIT}
WORKDIR /src
# Upstream's edison-osip.dat is empty, which makes u-boot-edison.img unusable with
# xFSTK (see scripts/mkosip.py). Generate the real header before binman runs.
COPY scripts/mkosip.py /usr/local/bin/
RUN test ! -s board/intel/edison/edison-osip.dat \
 || { echo "upstream edison-osip.dat is no longer empty; review mkosip.py" >&2; exit 1; }
RUN python3 /usr/local/bin/mkosip.py board/intel/edison/edison-osip.dat
RUN make O=/build edison_defconfig \
 && make O=/build -j"$(nproc)"
# The IFWI expects 4 KiB of zeros in front of U-Boot; mainline's build adds them.
RUN test "$(head -c 4096 /build/u-boot.bin | tr -d '\000' | wc -c)" -eq 0 \
 || { echo "u-boot.bin is missing its 4 KiB zero prefix" >&2; exit 1; }
# binman places U-Boot at 0x200 *without* the 4 KiB prefix, but U-Boot is linked at
# 0x1101000 and the OSIP loads the image at 0x1100000. Overwrite it with the prefixed
# u-boot.bin, which is also exactly what DFU writes to u-boot0. The environments at
# 0x200200 and 0x500200 are left as binman placed them.
RUN test "$(stat -c %s /build/u-boot.bin)" -lt $((0x200000)) \
 && dd if=/build/u-boot.bin of=/build/u-boot-edison.img bs=512 seek=1 conv=notrunc status=none \
 && cmp -n "$(stat -c %s /build/u-boot.bin)" -i 512:0 /build/u-boot-edison.img /build/u-boot.bin
# The OSIP header declares a 6 MiB OS image after it; pad the image to match, and check
# the header actually made it in.
RUN truncate -s $((512 + 6 * 1024 * 1024)) /build/u-boot-edison.img \
 && test "$(head -c 4 /build/u-boot-edison.img)" = '$OS$' \
 || { echo "u-boot-edison.img has no OSIP header" >&2; exit 1; }
RUN cd /build && sha256sum u-boot.bin u-boot-edison.img > SHA256SUMS \
 && git -C /src describe --tags --exact-match > VERSION

FROM scratch
COPY --from=build /build/u-boot.bin /build/u-boot-edison.img /build/SHA256SUMS /build/VERSION /
