#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

source ./scripts/lib/manifests.sh.inc

# Apply our actual network policies, ideally the core policies would get added during the init phase
# so we could enter enforcing mode here but the job executes fast enough the CRD definitions are
# not ready.
#
# I might be able to work around the issue by creating a separate manifest for the network policies
# and applying them independently... Could give me a better organization structure around them as
# well.
manifest_apply cilium/bootstrap

# Local path provisioner then vault

#manifest_apply vault/bootstrap

# Everything added to the cluster needs to have these policies enforced on them. The earlier things
# get kicked out for being out of spec the faster I can fix them.
manifest_apply kyverno/bootstrap

# We also want to start monitoring for security related events coming from the kubernetes audit logs
# (TODO: needs to be configured during cluster initialization, though I'd prefer to figure out a way
# for ArgoCD to also manage that...)
manifest_apply falco/bootstrap

# Ceph fails after multiple runs due to the operator taking over control of some of the resources.
# Some of these values are resource definitions and are very weird to take over. I bet I could
# solve this by using the patch delete syntax.
#manifest_apply rook-ceph/bootstrap || true

#manifest_apply argocd/bootstrap
