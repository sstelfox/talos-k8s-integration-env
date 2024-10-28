#!/usr/bin/env sh

set -o errexit

mkdir -p _out/

if [ ! -f _out/uki-signing-key.pem ]; then
  talosctl gen secureboot uki --common-name "Firmament SecureBoot Key"
fi

if [ ! -f _out/pcr-signing-key.pem ]; then
  talosctl gen secureboot pcr
fi

COMMON_IMAGER_OPTIONS="--arch amd64 --extra-kernel-arg net.ifnames=0"

podman run --rm -t -v ${PWD}/_out:/secureboot:ro -v $PWD/_out:/out \
  ghcr.io/siderolabs/imager:v1.8.1 secureboot-installer \
  ${COMMON_IMAGER_OPTIONS}

podman run --rm -t -v ${PWD}/_out:/secureboot:ro -v $PWD/_out:/out \
  ghcr.io/siderolabs/imager:v1.8.1 secureboot-iso --arch amd64 \
  ${COMMON_IMAGER_OPTIONS}

podman run --rm -t -v ${PWD}/_out:/out ghcr.io/siderolabs/imager:v1.8.0 iso --output-kind kernel
podman run --rm -t -v ${PWD}/_out:/out ghcr.io/siderolabs/imager:v1.8.0 iso --output-kind initramfs
