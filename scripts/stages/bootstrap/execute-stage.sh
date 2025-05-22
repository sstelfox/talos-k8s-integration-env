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

echo "entering bootstrap phase" >&2

# We want to start this stage off getting kyverno into the cluster so we can stop omitting the
# policies and policy exceptions from our manifests. It's also good to ensure policy enforcement as
# soon as possible so non-compliant resources can't sneak in without notice.
manifest_apply kyverno/bootstrap

# Next we'll get our CNI setup in a better shape, ensure all inter-service traffic is encrypted.
# This is also where we'll start enforcing networking policies so everything before this manifest
# should have network policies already defined.
#manifest_apply cilium/bootstrap

# We don't have our logging and observability stack up to really make use of these audit logs, but
# it will begin capturing them. We want to ensure our security enforcement and monitoring
# mechanisms are avilable before we hand off the cluster to argocd.
#manifest_apply falco/bootstrap

#manifest_apply argocd/bootstrap
