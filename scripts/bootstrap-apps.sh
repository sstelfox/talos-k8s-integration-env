#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

source ./scripts/lib/manifests.sh.inc

manifest_apply kyverno/bootstrap
manifest_apply kyverno-policies/bootstrap

# This needs work and I probably need to render out the manifest and use the job to apply it inline
# instead of using the cilium-install CI image to prevent the management transition.
manifest_apply cilium/bootstrap

#manifest_apply rook-ceph/bootstrap
#manifest_apply argocd/bootstrap

# Just trying this out, haven't decided whether I want to use it or not. Meshery requires rook-ceph
# volumes to be setup...
#
# This is pretty unstable and requires crazy amounts of resources. I'll leave the manifest around
# for now but mostly as a warning to myself and others to avoid it for now...
#manifest_apply meshery/bootstrap
