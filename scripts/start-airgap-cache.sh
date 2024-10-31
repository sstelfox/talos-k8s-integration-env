#!/usr/bin/env sh

set -o errexit
set -o pipefail

REGISTRY_CONTAINER_NAME="airgap-registry"

# Initialize our image list with the official ones
IMAGE_LIST=$(talosctl image default)

add_image_to_list() {
  local new_image="${1:-}"

  if [ -z "${new_image}" ]; then
    echo "usage: add_image_to_list IMAGE_REF"
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
    echo "usage: is_image_in_list IMAGE_REF"
    exit 127
  fi

  printf '%s\n' "${IMAGE_LIST}" | grep -Fx "${image_name}" 2>&1 >/dev/null
}

launch_airgap_cache_registry() {
  mkdir -p airgap_registry/

  if ! podman container exists ${REGISTRY_CONTAINER_NAME}; then
    podman run -d -p 6000:5000 --replace --name ${REGISTRY_CONTAINER_NAME} \
      --mount type=bind,src=${PWD}/airgap_registry,dst=/var/lib/registry \
      docker.io/library/registry:2
  else
    if ! podman container inspect ${REGISTRY_CONTAINER_NAME} --format '{{.State.Running}}' | grep -q "true"; then
      podman start ${REGISTRY_CONTAINER_NAME}
    fi
  fi
}

populate_cache_with_image() {
  local image_ref="${1-}"

  if [ -z "${image_ref}" ]; then
    echo "usage: populate_cache_with_image IMAGE_REF"
    return 1
  fi

  local dest_image
  dest_image="docker://127.0.0.1:6000/$(echo ${image_ref} | cut -d'/' -f2-)"

  if skopeo inspect --tls-verify=false "${dest_image}" 2>&1 >/dev/null; then
    echo "image already exists in local registry: ${image_ref}"
    return 0
  fi

  if ! skopeo copy "docker://${image_ref}" --dest-tls-verify=false "${dest_image}" 2>&1 >/dev/null; then
    echo "error: failed to copy image"
    return 1
  fi

  echo "successfully copied image to local registry: ${image_ref}"
  return 0
}

populate_airgap_cache() {
  printf '%s\n' "${IMAGE_LIST}" | while IFS= read -r image; do
    populate_cache_with_image $image
  done
}

launch_airgap_cache_registry

add_image_to_list docker.io/library/nginx:alpine

populate_airgap_cache
