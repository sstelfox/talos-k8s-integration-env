#!/usr/bin/env sh

launch_airgap_cache_registry() {
  mkdir -p cached_images/airgap

  podman run -d -p 6000:5000 \
    --replace --name registry-airgapped \
    --mount type=bind,src=$(pwd)/cached_images/ghcr,dst=/var/lib/registry \
    docker.io/library/registry:2
}

populate_airgap_cache() {
  for image in $(talosctl image default); do
    podman pull ${image}

    local new_image_name
    new_image_name="$(echo $image | sed -E 's#^[^/]+/#127.0.0.1:6000/#')"

    podman tag ${image} ${new_image_name}
    podman push ${new_image_name}
  done
}

mkdir -p ~/.talos/clusters

# The airgap registry is simpler than the cacheing registry...
launch_airgap_cache_registry
populate_airgap_cache

sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
    --extra-uefi-search-paths /usr/share/ovmf/x64/ \
    --registry-mirror docker.io=http://10.5.0.1:6000 \
    --registry-mirror registry.k8s.io=http://10.5.0.1:6000 \
    --registry-mirror gcr.io=http://10.5.0.1:6000 \
    --registry-mirror ghcr.io=http://10.5.0.1:6000
