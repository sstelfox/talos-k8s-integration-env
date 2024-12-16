#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# This is expected to be run from the root of the repo

source ./scripts/cfg/talos.sh.inc

# Generate a fresh schematic:
FACTORY_ID="$(curl -X POST --data-binary @firmament_integration/source_installer/talos-secure-imagefactory-schematic.yaml https://factory.talos.dev/schematics | jq -r .id)"

curl -o ./_out/metal-${TALOS_ARCH}-${TALOS_VERSION}-secureboot.iso \
  https://factory.talos.dev/image/${FACTORY_ID}/${TALOS_VERSION}/metal-${TALOS_ARCH}-secureboot.iso

INSTALLER_IMAGE="factory.talos.dev/installer-secureboot/${FACTORY_ID}:${TALOS_VERSION}"

skopeo copy --insecure-policy docker://${INSTALLER_IMAGE} \
  oci-archive:./_out/installer-${TALOS_ARCH}-${TALOS_VERSION}-secureboot.tar
