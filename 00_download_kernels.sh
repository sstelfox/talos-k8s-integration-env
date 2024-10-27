#!/bin/sh

mkdir -p _out/

TALOS_ARCH="amd64"
TALOS_VERSION="v1.8.1"

curl https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/vmlinuz-${TALOS_ARCH} -L -o _out/vmlinuz-${TALOS_ARCH}
curl https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/initramfs-${TALOS_ARCH}.xz -L -o _out/initramfs-${TALOS_ARCH}.xz
