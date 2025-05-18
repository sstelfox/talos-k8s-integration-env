#!/usr/bin/env bash

set -euo pipefail

# Once vault is secure and has a baseline CA, our next step in the vault integration is using a
# vault controlled certificate to manage the kubernetes node and api certificates. This won't
# actually switch the cluster over to using them as we'll need to patch the machine configs to
# switch this authority over.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/vault.sh.inc"

VAULT_ROOT_KEY="$(get_vault_root_key)"
VAULT_CN="vault.vault.svc.${CLUSTER_DOMAIN}"
