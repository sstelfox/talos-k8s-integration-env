#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster but not much else.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/manifests.sh.inc"

STAGE_DIRECTORY="${REPO_ROOT_DIR}/scripts/stages/init"

echo "entering init phase" >&2

# Local path provisioner to provide minimal storage for vault. We don't use it for much, vault
# replicates on its own, and ensures everything on disk is encrypted. It needs to come up before
# any other service needs secrets.
manifest_apply local-path-provisioner/init
manifest_apply csi-driver-nfs/init

# This is a pretty insecure and non-HA deployment, we'll use it to bootstrap managing itself and the
# reset of the cluster certificates including the node certificates. We use the local path
# provisioner here which is safe due to the raft replication and inherent encryption vault always
# uses. This does not have an audit log but that will be provisioned once ceph comes online.
manifest_apply vault/init-pre

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
manifest_apply vault/init-post

# We ultimately want our kubernetes API and node authentication to be using an internally managed
# and monitored CA.
${STAGE_DIRECTORY}/vault-kube-integration.sh

manifest_apply cert-manager/init

# Next up is storage
manifest_apply rook-ceph-operator/init
manifest_apply rook-ceph-cluster/init

# This takes a hot second, but all future stages need to have working storage so we're going to
# block the continued execution until this is ready.
echo "waiting for ceph storage cluster to become ready..." &>/dev/null
kubectl wait --for=jsonpath='{.status.phase}'=Ready cephclusters.ceph.rook.io/rook-ceph \
  -n rook-ceph --all --timeout=20m &>/dev/null

# There is still quite a bit of time here before the storage is actually available. The cluster is
# valid and being deployed at this point, but the monitors, and storage devices haven't yet been
# deployed. We just need the monitors to come up before we can start tuning it.
kubectl wait --for=condition=Ready pods -l app=rook-ceph-mon -n rook-ceph --all \
  --timeout=10m &>/dev/null

${STAGE_DIRECTORY}/tune-ceph-storage.sh

# We then need to wait for all the OSDs to prepare the disks and prep them for use.
echo "waiting for ceph data services to become ready..." >&2
kubectl wait --for=condition=Ready pods -l app=rook-ceph-osd -n rook-ceph --all \
  --timeout=10m &>/dev/null

echo "ceph storage is ready" >&2

# We don't always want to run this

# Lastly there is an external NFS server available over NFS we want to expose to our containers. We
# mind as well set this up now.
#${STAGE_DIRECTORY}/setup-nfs-wireguard-config.sh

#manifest_apply wireguard-nfs-volumes/init
