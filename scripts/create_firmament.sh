#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

if [ ! -f "./_out/vmlinuz-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}" ] || [ ! -f "./_out/initramfs-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.xz" ]; then
  echo 'error: need kernel and initramfs before the integration cluster can be booted' >&2
  exit 1
fi

if [ "${EUID}" = "0" ]; then
  echo "this script will ask for sudo permission itself, do not run it additionally with sudo"
  exit 2
fi

source talos/firmament/_patch_config.sh.inc

# This is a workaround, talosctl needs to run as root and will create the kube config with root
# permissions and ownership if it doesn't exist already. This will break the later parts of the
# script that try and use kubectl to verify the health of the cluster.
mkdir -p ~/.kube ~/.talos/clusters
touch ~/.kube/config

# May need the following when I go bare metal... Maybe
# --iso-path=./_out/metal-${TALOS_ARCH}-${TALOS_VERSION}.iso --skip-injecting-config --with-apply-config

# * The CNI bundle is the only one on the list below that is downloaded by the system running this
#   script. That qemu network address is still accessible to this host so we use it for consistency
#  --image 10.5.0.1:6000/siderolabs/talos:${TALOS_VERSION} \
#  --install-image 10.5.0.1:6000/siderolabs/installer:${TALOS_VERSION}
#  --image ghcr.io/siderolabs/talos:${TALOS_VERSION} \
#  --install-image ghcr.io/siderolabs/installer:${TALOS_VERSION}
sudo --preserve-env=HOME ./_out/talosctl cluster create --provisioner qemu \
  --name ${TALOS_CLUSTER_NAME} --talos-version ${TALOS_VERSION} --controlplanes 3 --workers 2 \
  --vmlinuz-path=./_out/vmlinuz-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION} \
  --initrd-path=./_out/initramfs-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.xz \
  --extra-uefi-search-paths /usr/share/ovmf/x64/ --with-tpm2 --with-uefi \
  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
  --disk 6148 --extra-disks 1 --extra-disks-size 10240 \
  --install-image ghcr.io/siderolabs/installer:${TALOS_VERSION} \
  --image ghcr.io/siderolabs/talos:${TALOS_VERSION} \
  --cni-bundle-url http://10.5.0.1:6100/talosctl-cni-bundle-${TALOS_SOURCE}-${TALOS_ARCH}-${TALOS_VERSION}.tar.gz \
  ${shared_patches} ${control_plane_patches} ${worker_patches}

if [ $? -ne 0 ]; then
  # We're going to want to diagnose why the bring-up failed, setup the kubeconfig so we can just do
  # that.
  ./_out/talosctl kubeconfig --force-context-name ${TALOS_CLUSTER_NAME} -n 10.5.0.2 --force >/dev/null 2>&1

  echo 'error: failed to create the firmament integration cluster' >&2
  exit 3
fi

#echo 'Waiting for Cilium network to become healthy...'
#if ! timeout 5m cilium status --wait; then
#  echo 'Network never stabilized...'
#  exit 4
#fi

# Once the cluster is initially bootstrapped we want to verify that our the fundamental internal
# networking is working. All of our subsequent tests and use of the cluster rely on the cluster
# having sane networking.
#
# This test does deploy privileged containers into the cluster and tried to clean up after itself,
# but we should avoid running it on the production airgap cluster.
#./tests/cilium/validate_core.sh
