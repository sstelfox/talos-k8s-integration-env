#!/usr/bin/env sh

set -o errexit

source talos/firmament/_patch_config.sh.inc

mkdir -p ~/.talos/clusters
# --iso-path=./_out/metal-amd64.iso --skip-injecting-config --with-apply-config \

sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
  ${shared_patches} ${control_plane_patches} ${worker_patches} \
  --extra-uefi-search-paths /usr/share/ovmf/x64/ --with-tpm2 --with-uefi \
  --name firmament-integration --controlplanes 1 --workers 1 \
  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
  --disk 6144 --extra-disks 1 --extra-disks-size 5120

sudo chown -R sstelfox:sstelfox ${HOME}/.talos ${HOME}/.kube
