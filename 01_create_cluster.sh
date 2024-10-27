#!/usr/bin/env sh

launch_cacheing_container_registries() {
  mkdir -p cached_images/{docker,k8s,gcr,ghcr}

  # Each registry only supports a single upstream so we need to start one for each of the required
  # upstreams.
  podman run -d -p 5000:5000 -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
    --read-only --replace --name registry-docker.io --userns keep-id:uid=999,gid=999 \
    --mount type=bind,src=$(pwd)/cached_images/docker,dst=/var/lib/registry \
    docker.io/library/registry:2

  podman run -d -p 5001:5000 -e REGISTRY_PROXY_REMOTEURL=https://registry.k8s.io \
    --read-only --replace --name registry-registry.k8s.io --userns keep-id:uid=999,gid=999 \
    --mount type=bind,src=$(pwd)/cached_images/k8s,dst=/var/lib/registry \
    docker.io/library/registry:2

  podman run -d -p 5003:5000 -e REGISTRY_PROXY_REMOTEURL=https://gcr.io \
    --read-only --replace --name registry-gcr.io --userns keep-id:uid=999,gid=999 \
    --mount type=bind,src=$(pwd)/cached_images/gcr,dst=/var/lib/registry \
    docker.io/library/registry:2

  podman run -d -p 5004:5000 -e REGISTRY_PROXY_REMOTEURL=https://ghcr.io \
    --read-only --replace --name registry-ghcr.io --userns keep-id:uid=999,gid=999 \
    --mount type=bind,src=$(pwd)/cached_images/ghcr,dst=/var/lib/registry \
    docker.io/library/registry:2
}

mkdir -p ~/.talos/clusters

launch_cacheing_container_registries

sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
    --extra-uefi-search-paths /usr/share/ovmf/x64/ \
    --registry-mirror docker.io=http://10.5.0.1:5000 --registry-mirror registry.k8s.io=http://10.5.0.1:5001 \
    --registry-mirror gcr.io=http://10.5.0.1:5003 --registry-mirror ghcr.io=http://10.5.0.1:5004
