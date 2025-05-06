#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

source ./scripts/lib/manifests.sh.inc

# Apply our actual network policies, ideally the core policies would get added during the init phase
# so we could enter enforcing mode here but the job executes fast enough the CRD definitions are
# not ready.
manifest_apply cilium/bootstrap

# Local path provisioner then vault
manifest_apply local-path-provisioner/stable

# Initial insecure version
manifest_apply vault/init

# Need to generate certificates vault will use, should replace these later on
#./scripts/generate-vault-tls.sh

# Everything added to the cluster needs to have these policies enforced on them. The earlier things
# get kicked out for being out of spec the faster I can fix them.
#manifest_apply kyverno/bootstrap

# We also want to start monitoring for security related events coming from the kubernetes audit logs
# (TODO: needs to be configured during cluster initialization, though I'd prefer to figure out a way
# for ArgoCD to also manage that...)
#manifest_apply falco/bootstrap

# Ceph fails after multiple runs due to the operator taking over control of some of the resources.
# Some of these values are resource definitions and are very weird to take over. I bet I could
# solve this by using the patch delete syntax.
#manifest_apply rook-ceph/bootstrap || true

#manifest_apply argocd/bootstrap

# Apply our actual network policies, ideally the core policies would get added earlier but for now
# while building up the core its an extra diagnostic headache. This can't be fully done during the
# init phase as the job doesn't execute fast enough for CRDs to be installed and usable when its
# evaluated.
#manifest_apply cilium/stable
