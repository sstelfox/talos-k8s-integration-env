#!/usr/bin/env sh

podman kill talos-airgap-registry >/dev/null 2>&1
podman rm -fv talos-airgap-registry >/dev/null 2>&1

podman kill talos-manifest-server >/dev/null 2>&1
podman rm -fv talos-manifest-server >/dev/null 2>&1

rm -rf airgap_registry/ _out/
