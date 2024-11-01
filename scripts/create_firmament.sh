#!/usr/bin/env sh

set -o errexit

TALOS_ARCH="amd64"
TALOS_VERSION="v1.8.2"

if [ ! -f "./_out/vmlinuz-${TALOS_ARCH}-${TALOS_VERSION}" ] || [ ! -f "./_out/initramfs-${TALOS_ARCH}-${TALOS_VERSION}.xz" ]; then
  echo 'error: need kernel and initramfs before the integration cluster can be booted' >&2
  exit 1
fi

source talos/firmament/_patch_config.sh.inc

mkdir -p ~/.talos/clusters

# TODO: switch the images to a local pull so I can switch to custom builds and handle this in the airgap env
# TODO: build up the arguments for the installer piecemeal to allow selection of different install paths such as ISO vs kernel:
# --iso-path=./_out/metal-${TALOS_ARCH}-${TALOS_VERSION}.iso --skip-injecting-config --with-apply-config \
# --image=ghcr.io/siderolabs/talos:${TALOS_VERSION} --install-image=ghcr.io/siderolabs/installer:${TALOS_VERSION} \

sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
  ${shared_patches} ${control_plane_patches} ${worker_patches} \
  --extra-uefi-search-paths /usr/share/ovmf/x64/ --with-tpm2 --with-uefi \
  --name firmament-integration --controlplanes 3 --workers 2 \
  --vmlinuz-path=./_out/vmlinuz-${TALOS_ARCH}-${TALOS_VERSION} \
  --initrd-path=./_out/initramfs-${TALOS_ARCH}-${TALOS_VERSION}.xz \
  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
  --disk 6144 --extra-disks 1 --extra-disks-size 5120

# Once the cluster is initially bootstrapped we want to verify that our the fundamental internal
# networking is working. All of our subsequent tests and use of the cluster rely on the cluster
# having sane networking.
#
# This test does deploy privileged containers into the cluster and tried to clean up after itself,
# but we should avoid running it on the production airgap cluster.
./tests/cilium/validate_core.sh
