#!/usr/bin/env sh

set -o errexit

mkdir -p ~/.talos/clusters

sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
    --extra-uefi-search-paths /usr/share/ovmf/x64/ \
    --registry-mirror docker.io=http://10.5.0.1:6000 \
    --registry-mirror registry.k8s.io=http://10.5.0.1:6000 \
    --registry-mirror gcr.io=http://10.5.0.1:6000 \
    --registry-mirror ghcr.io=http://10.5.0.1:6000 \
    --name firmament-integration --dns-domain firmament-integration.k8s.grayiron.io \
    --disk-encryption-key-types kms --encrypt-ephemeral --encrypt-state --with-tpm2 --with-uefi \
    --controlplanes 3 --workers 2 \
    --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
    --disk 6144 --extra-disks 1 --extra-disks-size 5120

sudo chown -R sstelfox:sstelfox ${HOME}/.talos
