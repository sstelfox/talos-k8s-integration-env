#!/usr/bin/env bash

set -euo pipefail

source ./scripts/lib/manifests.sh.inc

# These manifests are run and installed before the cluster is fully up. These can not rely on the
# availability of in-cluster networking or resources. The only manifests that should be present in
# the init section are those required to establish these core service workloads. Anything that can
# be delayed until later, or more complex pieces that require services should take place in later
# deploys.
manifest_render cilium/init

# We use LPP temporarily for vault before our actual cluster storage is available
./manifests/local-path-provisioner/stable/update.sh
manifest_render local-path-provisioner/stable

# This is a pretty insecure and non-HA deployment, we'll use it to bootstrap managing itself and the
# reset of the cluster certificates including the node certificates. We use the local path
# provisioner here which is safe due to the raft replication and inherent encryption vault always
# uses. This does not have an audit log but that will be provisioned once ceph comes online.
manifest_render vault/init

#manifest_render rook-ceph/init

# Once the cluster is minimally up we need to prepare for it to be taken over by ArgoCD. No
# applications should be defined in here, only cluster-wide services. The priority here is getting
# the protection and support resources up and available so they're ready for ArgoCD to deploy our
# intended workloads.
#manifest_render cilium/bootstrap
#manifest_render falco/bootstrap
#manifest_render kyverno/bootstrap

#manifest_render rook-ceph/bootstrap
#manifest_render argocd/bootstrap
#manifest_render observability/bootstrap

# The remaining manifests should never be deployed manually as ArgoCD owns them. We still want to
# be able to render them with this script as we provide some early pre-commit sanity and security
# checks that must be passing for this repo to enter the production environment.
#
# Note: there currently are no cluster workloads defined in this repo
