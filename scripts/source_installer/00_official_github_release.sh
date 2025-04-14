#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# This is expected to be run from the root of the repo

source ./scripts/cfg/talos.sh.inc

BASE_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}"
SOURCE_KEY="github-official"

download_repo_release_file() {
  local file_base="${1:-}"
  local suffix="${2:-}"

  if [ -z "${file_base}" ]; then
    echo "usage: download_repo_release_file FILE [FILE_EXTENSION]"
    return 1
  fi

  # If we already have the specific source/arch/version don't download again...
  if [ -f "_out/${file_base}-${SOURCE_KEY}-${TALOS_ARCH}-${TALOS_VERSION}${suffix}" ]; then
    echo "already have ${file_base}${suffix} for talos/${TALOS_VERSION}-${TALOS_ARCH}" >&2
    return 0
  fi

  mkdir -p _out/

  echo "downloading ${file_base}${suffix} for talos/${TALOS_VERSION}-${TALOS_ARCH}" >&2
  curl -s ${BASE_URL}/${file_base}-${TALOS_ARCH}${suffix} -L -o _out/${file_base}-${SOURCE_KEY}-${TALOS_ARCH}-${TALOS_VERSION}${suffix}
}

download_repo_release_file talosctl-linux

download_repo_release_file vmlinuz
download_repo_release_file initramfs .xz
#download_repo_release_file metal .iso
#download_repo_release_file talosctl-cni-bundle .tar.gz

# Ensure we use a matching talosctl binary
(
  cd ./_out

  rm -f talosctl
  ln -s talosctl-linux-${SOURCE_KEY}-${TALOS_ARCH}-${TALOS_VERSION} talosctl
  chmod +x talosctl
)

# Ensure the CNI bundle we downloaded is available via the local web server if it isn't already
#CNI_BUNDLE_FILE="talosctl-cni-bundle-${SOURCE_KEY}-${TALOS_ARCH}-${TALOS_VERSION}.tar.gz"
#CNI_BUNDLE_FULL_PATH="./_out/public/${CNI_BUNDLE_FILE}"

#if [ ! -f "${CNI_BUNDLE_FULL_PATH}" ]; then
#  mkdir -p "$(dirname "${CNI_BUNDLE_FULL_PATH}")"
#  cp -f "./_out/${CNI_BUNDLE_FILE}" "${CNI_BUNDLE_FULL_PATH}"
#fi
