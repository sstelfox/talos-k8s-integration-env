#!/usr/bin/env sh

set -o errexit

mkdir -p _out/

TALOS_VERSION="v1.8.1"

if [ ! -f _out/uki-signing-key.pem ]; then
  talosctl gen secureboot uki --common-name "Firmament SecureBoot Key"
fi

if [ ! -f _out/pcr-signing-key.pem ]; then
  talosctl gen secureboot pcr
fi

# ## Kernel Overrides:
#
# ### Predictable Interface Names
#
# Relevant entries:
#
# * `net.ifnames=0`
#
# Predictable names for the network interfaces allow us to pre-configure the roles and services
# relying on knowing the specific interface name such as a cluster VIP. Since in our virtualized
# environment we can guarantee there is always exactly one non-loopback network interface we don't
# have to worry about the wrong interface being selected.
#
# This is notably not true in the firmament deployment plans which should omit this option.
#
# ### Interactive Console Dashboard
#
# * `talos.dashboard.disabled=1`
#
# Our virtual machine console's are not exposed to any form of management EXCEPT in the firmament
# case. We do not want to leave an administrative running where we have no intention of using it.
COMMON_IMAGER_OPTIONS="--arch amd64 --extra-kernel-arg net.ifnames=0 --extra-kernel-arg talos.dashboard.disabled=1"

podman run --rm -t -v ${PWD}/_out:/secureboot:ro -v $PWD/_out:/out \
  ghcr.io/siderolabs/imager:${TALOS_VERSION} secureboot-installer \
  ${COMMON_IMAGER_OPTIONS}

# WARNING: The downloader and cluster creation script do not use the file output from this (it has
# a different name)
podman run --rm -t -v ${PWD}/_out:/secureboot:ro -v $PWD/_out:/out \
  ghcr.io/siderolabs/imager:${TALOS_VERSION} secureboot-iso \
  ${COMMON_IMAGER_OPTIONS}

#podman run --rm -t -v ${PWD}/_out:/out ghcr.io/siderolabs/imager:${TALOS_VERSION} iso --output-kind kernel
#podman run --rm -t -v ${PWD}/_out:/out ghcr.io/siderolabs/imager:${TALOS_VERSION} iso --output-kind initramfs
