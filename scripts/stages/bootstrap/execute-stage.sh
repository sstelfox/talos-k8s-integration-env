#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster but not much else.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/manifests.sh.inc"

STAGE_DIRECTORY="${REPO_ROOT_DIR}/scripts/stages/bootstrap"

# Local path provisioner to provide minimal storage for vault. We don't use it for much, vault
# replicates on its own, and ensures everything on disk is encrypted. It needs to come up before
# any other service needs secrets.
manifest_apply local-path-provisioner/stable

# This is a pretty insecure and non-HA deployment, we'll use it to bootstrap managing itself and the
# reset of the cluster certificates including the node certificates. We use the local path
# provisioner here which is safe due to the raft replication and inherent encryption vault always
# uses. This does not have an audit log but that will be provisioned once ceph comes online.
manifest_apply vault/init

# Vault requires some manual initialization and unsealing before it will become ready and we can
# move on. This script sets up the initial vault before we switch to the HA and secure mode. The
# service is not save to use yet as transport encryption is not available for the service. This
# bootstrap process runs the initialization inside the running container.
#
# todo(sstelfox): the root token is transmitted use the kubectl exec output, I need to ensure that
# connection is encrypted before that transfer occurs.
${STAGE_DIRECTORY}/initialize-vault.sh

# With vault initialized we should be able to take the next step in our security, turning on TLS
# encryption for Vault and setting it up for the initial cluster services. This still isn't fully
# configured, it needs
manifest_apply vault/bootstrap

# Apply our actual network policies, ideally the core policies would get added during the init phase
# so we could enter enforcing mode here but the job executes fast enough the CRD definitions are
# not ready.
#manifest_apply cilium/bootstrap

# Need to generate certificates vault will use, should replace these later on
#./scripts/generate-vault-tls.sh

# Everything added to the cluster needs to have these policies enforced on them. The earlier things
# get kicked out for being out of spec the faster I can fix them.
#manifest_apply kyverno/bootstrap

# We also want to start monitoring for security related events coming from the kubernetes audit logs
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
