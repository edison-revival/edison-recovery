# xfstk-dldr-solo built from edison-fw/xFSTK, pinned to an exact commit and base image.
ARG BASE=ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

FROM ${BASE} AS build
# edison-fw/xFSTK tag v1.8.6
ARG XFSTK_COMMIT=989617b8308af2f7dd81f23aac3ce3b0aafc38f8
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git g++ make cmake doxygen \
      qtbase5-dev libxml2-dev libusb-dev libboost-program-options-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/edison-fw/xFSTK.git /src \
 && git -C /src checkout --detach ${XFSTK_COMMIT}
COPY patches/xfstk-*.patch /patches/
RUN for p in /patches/*.patch; do git -C /src apply --recount --verbose "$p" || exit 1; done
WORKDIR /build
# doxygen is only needed because the CMake config refuses to run without it.
RUN BUILD_VERSION=1.8.6 cmake /src \
 && make -j"$(nproc)" xfstk-dldr-solo

FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libqt5core5t64 libboost-program-options1.83.0 libusb-0.1-4 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /build/ancillary/configure/core/downloader-solo/xfstk-dldr-solo /usr/local/bin/
ENTRYPOINT ["xfstk-dldr-solo"]
