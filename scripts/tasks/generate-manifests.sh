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

## Begin cluster initialization
##
## Objective: Get storage, secrets, and networking up and stable enough to build from. Subsequent
## stages may refine the configurations of the services setup here, but the resources should all be
## up, all traffic should be encrypted, secrets protected and encrypted in vault, and storage usable
## with FDE enabled.
##
## Does not include authentication or authorization mechanisms

manifest_render cilium/init
manifest_render local-path-provisioner/init

manifest_render vault/init
# Manual process lives here requiring this to have its own micro-stage
manifest_render vault/post-init

manifest_render rook-ceph-operator/init
manifest_render rook-ceph-cluster/init

## Begin policy bootstrap
##
## Objective: Ensure container security policies are applied consistently everywhere and all audit
## log sources are configured producing meaningful security logs.
##
## This does not include the consumer ## of logs, alerting, or actions that derive from log events.

#manifest_render cilium/bootstrap
#manifest_render falco/bootstrap
#manifest_render kyverno/bootstrap

#manifest_render rook-ceph/bootstrap

## Begin cluster management handoff
##
## Objective: Setup only the absolute minimal set of services required to get ArgoCD taking over
## the management of both the cluster and the apps deployed upon it. This largely consists of the
## code forge for hosting this repo for ArgoCD and ArgoCD itself.

#manifest_render argocd/bootstrap
#manifest_render observability/bootstrap

# The remaining manifests should never be deployed manually as ArgoCD owns them. We still want to
# be able to render them with this script as we provide some early pre-commit sanity and security
# checks that must be passing for this repo to enter the production environment.
#
# Note: there currently are no cluster workloads defined in this repo
