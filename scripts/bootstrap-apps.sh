#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

source ./scripts/lib/manifests.sh.inc

# Everything added to the cluster needs to have these policies enforced on them. The earlier things
# get kicked out for being out of spec the faster I can fix them.
manifest_apply kyverno/bootstrap
manifest_apply kyverno-policies/bootstrap

# We have an early sufficient network and the security policies we need to configure this. Our next
# network stage wants storage for flow and audit records so let's prepare it before we need it.
manifest_apply rook-ceph/bootstrap

# This needs work and I probably need to render out the manifest and use the job to apply it inline
# instead of using the cilium-install CI image to prevent the management transition.
manifest_apply cilium/bootstrap

#manifest_apply vault/bootstrap

#manifest_apply argocd/bootstrap

# Just trying this out, haven't decided whether I want to use it or not. Meshery requires rook-ceph
# volumes to be setup...
#
# This is pretty unstable and requires crazy amounts of resources. I'll leave the manifest around
# for now but mostly as a warning to myself and others to avoid it for now...
#manifest_apply meshery/bootstrap
