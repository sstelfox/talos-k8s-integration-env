#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# This is expected to be run from the root of the repo

TALOS_ARCH="amd64"
TALOS_VERSION="v1.8.2"

# Generate a fresh schematic:
FACTORY_ID="$(curl -X POST --data-binary @firmament_integration/source_installer/talos-secure-imagefactory-schematic.yaml https://factory.talos.dev/schematics | jq -r .id)"

curl -o ./_out/metal-${TALOS_ARCH}-secureboot-custom.iso \
  https://factory.talos.dev/image/${FACTORY_ID}/${TALOS_VERSION}/metal-${TALOS_ARCH}-secureboot.iso

INSTALLER_IMAGE="factory.talos.dev/installer-secureboot/${FACTORY_ID}:${TALOS_VERSION}"

skopeo copy --insecure-policy docker://${INSTALLER_IMAGE} oci-archive:./_out/installer-secureboot-${TALOS_VERSION}-custom.tar
