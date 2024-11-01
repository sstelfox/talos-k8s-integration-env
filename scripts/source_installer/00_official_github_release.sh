#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# This is expected to be run from the root of the repo

TALOS_ARCH="amd64"
TALOS_VERSION="v1.8.2"

BASE_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}"

mkdir -p _out/

curl ${BASE_URL}/vmlinuz-${TALOS_ARCH} -L -o _out/vmlinuz-${TALOS_ARCH}-${TALOS_VERSION}
curl ${BASE_URL}/initramfs-${TALOS_ARCH}.xz -L -o _out/initramfs-${TALOS_ARCH}-${TALOS_VERSION}.xz
curl ${BASE_URL}/metal-${TALOS_ARCH}.iso -L -o _out/metal-${TALOS_ARCH}-${TALOS_VERSION}.iso
