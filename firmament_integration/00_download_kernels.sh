#!/bin/sh

mkdir -p _out/

TALOS_ARCH="amd64"
TALOS_VERSION="v1.8.2"

BASE_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}"

mkdir -p _out/

curl ${BASE_URL}/vmlinuz-${TALOS_ARCH} -L -o _out/vmlinuz-${TALOS_ARCH}
curl ${BASE_URL}/initramfs-${TALOS_ARCH}.xz -L -o _out/initramfs-${TALOS_ARCH}.xz

#curl ${BASE_URL}/metal-${TALOS_ARCH}.iso -L -o _out/metal-${TALOS_ARCH}.iso
