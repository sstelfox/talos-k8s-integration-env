#!/usr/bin/env sh

set -o errexit
set -o pipefail

INCLUDE_TEST_IMAGES=true

MANIFEST_CONTAINER_NAME="talos-manifest-server"
REGISTRY_CONTAINER_NAME="talos-airgap-registry"

# Initialize our image list with the official ones
IMAGE_LIST=$(./_out/talosctl image default)

source ./scripts/cfg/talos.sh.inc
source ./scripts/lib/manifests.sh.inc
source ./scripts/lib/services.sh.inc

add_image_to_list() {
  local new_image="${1:-}"

  if [ -z "${new_image}" ]; then
    echo "usage: add_image_to_list IMAGE_REF" >&2
    exit 127
  fi

  if ! is_image_in_list ${new_image}; then
    IMAGE_LIST="${IMAGE_LIST}
${new_image}"
  fi
}

is_image_in_list() {
  local image_name="${1:-}"

  if [ -z "${image_name}" ]; then
    echo "usage: is_image_in_list IMAGE_REF" >&2
    exit 127
  fi

  printf '%s\n' "${IMAGE_LIST}" | grep -Fx "${image_name}" 2>&1 >/dev/null
}

launch_airgap_cache_registry() {
  mkdir -p airgap_registry/

  if ! service_check_available ${REGISTRY_CONTAINER_NAME}; then
    podman run -d -p 6000:5000 --replace --name ${REGISTRY_CONTAINER_NAME} \
      --mount type=bind,src=${PWD}/airgap_registry,dst=/var/lib/registry \
      docker.io/library/registry:2 >/dev/null 2>&1

    echo "fresh talos airgap image cache started up" >&2
  fi
}

launch_initial_manifest_server() {
  mkdir -p _out/manifests/

  if ! service_check_available ${MANIFEST_CONTAINER_NAME}; then
    podman run -d -p 6100:80 --replace --name ${MANIFEST_CONTAINER_NAME} \
      --mount type=bind,src=${PWD}/_out/manifests,dst=/usr/share/nginx/html,readonly \
      docker.io/library/nginx:alpine >/dev/null 2>&1

    echo "fresh talos manifest server started up" >&2
  fi
}

populate_cache_with_image() {
  local image_ref="${1-}"

  if [ -z "${image_ref}" ]; then
    echo "usage: populate_cache_with_image IMAGE_REF" 2>&1
    return 1
  fi

  local dest_image
  dest_image="docker://127.0.0.1:6000/$(echo ${image_ref} | cut -d'/' -f2-)"

  if skopeo inspect --tls-verify=false "${dest_image}" >/dev/null 2>&1; then
    echo "image already exists in local registry: ${image_ref}" 2>&1
    return 0
  fi

  echo "copying image '${image_ref}' into local cache..." 2>&1

  if ! skopeo copy "docker://${image_ref}" --dest-tls-verify=false "${dest_image}" 2>&1 >/dev/null; then
    echo "error: failed to copy image"
    return 1
  fi

  echo "successfully copied image to local registry: ${image_ref}" 2>&1
  return 0
}

populate_airgap_cache() {
  printf '%s\n' "${IMAGE_LIST}" | while IFS= read -r image; do
    populate_cache_with_image $image
  done
}

# TODO: All images should be referenced using immutable tags

add_image_to_list ghcr.io/siderolabs/installer:${TALOS_VERSION}
add_image_to_list ghcr.io/siderolabs/talos:${TALOS_VERSION}

add_image_to_list docker.io/library/nginx:alpine
add_image_to_list docker.io/library/registry:2

#add_image_to_list quay.io/cilium/cilium:latest
add_image_to_list quay.io/cilium/cilium-cli-ci:latest
add_image_to_list quay.io/cilium/cilium-envoy:latest

if [ "${INCLUDE_TEST_IMAGES}" = "true" ]; then
  add_image_to_list quay.io/cilium/alpine-curl:v1.7.0
  add_image_to_list quay.io/cilium/json-mock:v1.3.5
  #add_image_to_list quay.io/cilium/network-perf:a816f935930cb2b40ba43230643da4d5751a5711@sha256:679d3a370c696f63884da4557a4466f3b5569b4719bb4f86e8aac02fbe390eea
fi

launch_airgap_cache_registry
populate_airgap_cache

# I've left this after the populate as I may be want to use the pulled image instead of referencing
# an upstream...
launch_initial_manifest_server

# Make sure we have a fresh copy of our Cilium initialization manifest
manifest_render cilium/init
