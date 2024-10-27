#!/usr/bin/env sh

set -o errexit

source machine_config_patches/_enabled_patches.sh.inc

mkdir -p ~/.talos/clusters

# We can't create a qemu cluster from already generated configs so we'll just apply the same
# patches for now. I may want to instead see if I can create than pull the configs
#sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
#  ${shared_patches} ${control_plane_patches} ${worker_patches} \
#  --talosconfig $(pwd)/_out/talosconfig --with-secrets $(pwd)/_out/secrets.yaml \
#  --controlplanes 3 --workers 2 \
#  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
#  --disk 6144 --extra-disks 1 --extra-disks-size 5120 \
#  --name firmament-integration \
#  --dns-domain firmament-integration.k8s.grayiron.io
# --disk-encryption-key-types kms --encrypt-ephemeral --encrypt-state --with-tpm2 --with-uefi \
# --extra-uefi-search-paths /usr/share/ovmf/x64/ \
# --registry-mirror ghcr.io=http://10.5.0.1:6000

#sudo chown -R sstelfox:sstelfox ${HOME}/.talos
