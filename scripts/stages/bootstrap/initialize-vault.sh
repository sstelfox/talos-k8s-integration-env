#!/usr/bin/env bash

set -euo pipefail

# This script expects to get run after the vault/init minimal bootstrap manifest is applied early
# on in the cluster setup. Vault requires it to be initialized and unsealed using an external
# process from the cluster which this script handles.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"
SECRETS_DIR="${REPO_ROOT_DIR}/_out/secrets"

# We need to wait for the container to come up. We can't rely on checking for the container to be
# "Ready" as there is a readiness check that will only succeed after the vault has been both
# initialized and unsealed.
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0 -n vault --timeout=30s
echo "pod ready beginning vault initialization" 2>&1

vault_func() {
  local user_cmd="$@"
  local full_cmd

  if [ -n "${VAULT_ROOT_KEY:-}" ]; then
    full_cmd="sh -c 'VAULT_TOKEN="${VAULT_ROOT_KEY}" vault ${user_cmd}'"
  else
    full_cmd="vault ${user_cmd}"
  fi

  eval "kubectl exec -n vault vault-0 -- ${full_cmd}"
}

# Initialize the actual vault, store the keys in our standard secrets directory
# todo(sstelfox): this should be encrypted and we may want to capture this as part of a DR package.
vault_func operator init >"${SECRETS_DIR}/vault-keys.txt"

get_root_key() {
  grep "Initial Root Token" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

get_unseal_key() {
  local id="${1:-}"
  grep "Unseal Key ${id}" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

# Now we need to unlock the initialized vault with the keys, we'll always use the first 3 in the
# quorum. These need to be protected and delegated appropriately to allow dead-man unlocks of the
# vault when automation fails. The root key should migrate to the breakglass audit access with
# custody provided by the C-suite.
vault_func operator unseal "$(get_unseal_key 1)"
vault_func operator unseal "$(get_unseal_key 2)"
vault_func operator unseal "$(get_unseal_key 3)"

VAULT_ROOT_KEY="$(get_root_key)"

# With vault up we can start configuring it, I may want to switch this to something like terraform
# but this is sufficient for now. Very short intervals here to battle test rotation procedures.
vault_func secrets enable -path=pki_root pki
vault_func secrets tune -max-lease-ttl=720h pki_root
vault_func write pki_root/root/generate/internal common_name='Cluster Root CA' ttl=720h
