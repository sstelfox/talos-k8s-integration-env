#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

source ./scripts/lib/manifests.sh.inc

# Used during cluster bring up
manifest_render cilium/init
#manifest_render rook-ceph/init

# Used post-boot
manifest_render cilium/bootstrap
manifest_render falco/bootstrap
manifest_render kyverno/bootstrap

manifest_render rook-ceph/bootstrap
manifest_render vault/bootstrap
manifest_render argocd/bootstrap
#manifest_render observability/bootstrap
