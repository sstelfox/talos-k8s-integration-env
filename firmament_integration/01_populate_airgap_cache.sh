#!/usr/bin/env sh

set -o errexit

launch_airgap_cache_registry() {
  mkdir -p cached_images/airgap

  podman run -d -p 6000:5000 \
    --replace --name registry-airgapped \
    --mount type=bind,src=${PWD}/cached_images/airgap,dst=/var/lib/registry \
    docker.io/library/registry:2
}

#populate_airgap_cache() {
#  for image in $(talosctl image default); do
#    skopeo copy docker://${image} docker://127.0.0.1:6000/${image} --dest-tls-verify=false
#  done
#}

populate_airgap_cache() {
  for image in $(talosctl image default); do
    podman pull ${image}

    local new_image_name
    new_image_name="$(echo $image | sed -E 's#^[^/]+/#127.0.0.1:6000/#')"

    podman tag ${image} ${new_image_name}
    podman push --tls-verify=false ${new_image_name}
  done
}

# The airgap registry is simpler than the cacheing registry...
launch_airgap_cache_registry
populate_airgap_cache
