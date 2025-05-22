#!/usr/bin/env bash

set -euo pipefail

source ./scripts/lib/manifests.sh.inc

# This script is intended as a sanity check against the manifests to ensure they're all generating
# correctly. This also provides a quick mechanism to see what existing policy failures are present
# (and will generate sample policies for making those exceptions). The manifests here are ordered
# roughly in the order that they're intended to be applied with comments indicating cluster creation
# stages as we enter them.
#
# This only includes the manifests and stages that are applied up till where ArgoCD takes over the
# cluster.
#
# The generated exceptions are almost always too broad and not always the correct way to remediate
# those warnings. The settings should be attempted to be corrected before writing an exception.
#
# Exceptions need to include a detailed description as to why that exception was present and how to
# check if its still necessary along with a timestamp indicating when the exception was created and
# separately when it was last reviewed. Exceptions must be reviewed quarterly.

# Required during initial cluster node bring up
manifest_render cilium/bring-up

## Begin cluster initialization
##
## Objective: Get storage, secrets, and networking up and stable enough to build from. Subsequent
## stages may refine the configurations of the services setup here, but the resources should all be
## up, all traffic should be encrypted, secrets protected and encrypted in vault, and storage usable
## with FDE enabled.
##
## Does not include authentication or authorization mechanisms

# Transitioning from the path provisioner to the static provisioner for the initial vault storage
manifest_render local-path-provisioner/init
manifest_render local-static-provisioner/init

# Manual process needs to happen halfway through vault's initial setup so this is split into two
# sections.
manifest_render vault/init-pre
manifest_render vault/init-post

manifest_render rook-ceph-operator/init
manifest_render rook-ceph-cluster/init

manifest_render cert-manager/init

manifest_render cilium/init

## Begin policy bootstrap

#manifest_render kyverno/bootstrap
#manifest_render cilium/bootstrap
#manifest_render falco/bootstrap

#manifest_render argocd/bootstrap

## Post-Argo
##
# The remaining manifests should never be deployed manually as ArgoCD owns them. We still want to
# be able to render them with this script as we provide some early pre-commit sanity and security
# checks that must be passing for this repo to enter the production environment.

#manifest_render observability/bootstrap
