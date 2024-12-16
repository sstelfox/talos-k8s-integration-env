#!/usr/bin/env sh

set -o errexit

source ./scripts/cfg/talos.sh.inc

if [ ! -f "./_out/vmlinuz-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}" ] || [ ! -f "./_out/initramfs-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.xz" ]; then
  echo 'error: need kernel and initramfs before the integration cluster can be booted' >&2
  exit 1
fi

source talos/firmament/_patch_config.sh.inc

mkdir -p ~/.talos/clusters

# TODO: switch the images to a local pull so I can switch to custom builds and handle this in the airgap env
# TODO: build up the arguments for the installer piecemeal to allow selection of different install paths such as ISO vs kernel:
# --iso-path=./_out/metal-${TALOS_ARCH}-${TALOS_VERSION}.iso --skip-injecting-config --with-apply-config \
# --image=ghcr.io/siderolabs/talos:${TALOS_VERSION} --install-image=ghcr.io/siderolabs/installer:${TALOS_VERSION} \

# Should be using the local registry for the installer even with the official image present here but
# I can't be sure of that and should test it...
sudo --preserve-env=HOME ./_out/talosctl cluster create --provisioner qemu \
  ${shared_patches} ${control_plane_patches} ${worker_patches} \
  --extra-uefi-search-paths /usr/share/ovmf/x64/ --with-tpm2 --with-uefi \
  --name ${TALOS_CLUSTER_NAME} --talos-version ${TALOS_VERSION} --controlplanes 3 --workers 2 \
  --vmlinuz-path=./_out/vmlinuz-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION} \
  --initrd-path=./_out/initramfs-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.xz \
  --install-image ghcr.io/siderolabs/installer:${TALOS_VERSION} \
  --image ghcr.io/siderolabs/talos:${TALOS_VERSION} \
  --cni-bundle-url http://10.5.0.1:6100/talosctl-cni-bundle-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.tar.gz \
  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
  --disk 6148 --extra-disks 1 --extra-disks-size 10240

if [ $? -ne 0 ]; then
  # We're going to want to diagnose why the bring-up failed, setup the kubeconfig so we can just do
  # that.
  ./_out/talosctl kubeconfig --force-context-name ${TALOS_CLUSTER_NAME} -n 10.5.0.2 --force >/dev/null 2>&1

  echo 'error: failed to create the firmament integration cluster' >&2
  exit 1
fi

echo 'Waiting for Cilium network to become healthy...'
if ! timeout 5m cilium status --wait; then
  echo 'Network never stabilized...'
  exit 1
fi

# Once the cluster is initially bootstrapped we want to verify that our the fundamental internal
# networking is working. All of our subsequent tests and use of the cluster rely on the cluster
# having sane networking.
#
# This test does deploy privileged containers into the cluster and tried to clean up after itself,
# but we should avoid running it on the production airgap cluster.
#./tests/cilium/validate_core.sh

#./scripts/bootstrap-apps.sh
