#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# We know at this point we have secret secret storage, secure and available persistent container
# storage, and stable but insecure networking with some additional configuration outstanding.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/manifests.sh.inc"

STAGE_DIRECTORY="${REPO_ROOT_DIR}/scripts/stages/bootstrap"

exit 1

# Our first step is get our CNI setup in a better shape, ensure all inter-service traffic is
# encrypted. This is also where we'll start enforcing networking policies so everything in the init
# stage should have network policies already defined.
#manifest_apply cilium/bootstrap

# Everything added to the cluster needs to have these policies enforced on them. The earlier things
# get kicked out for being out of spec the faster I can fix them.
#manifest_apply kyverno/bootstrap

# We also want to start monitoring for security related events coming from the kubernetes audit logs
#manifest_apply falco/bootstrap

#manifest_apply argocd/bootstrap
