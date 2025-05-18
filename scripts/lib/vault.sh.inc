#!/usr/bin/env false

get_vault_root_key() {
  if [ ! -f "${SECRETS_DIR}/vault-keys.txt" ]; then
    echo "vault root key doesn't yet exist" >&2
    return 1
  fi

  grep "Initial Root Token" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

get_vault_unseal_key() {
  local id="${1:-}"
  if [ -z "${id}" ]; then
    echo "must specify unseal key identity to unlock vault instance" >&2
    return 1
  fi

  if [ ! -f "${SECRETS_DIR}/vault-keys.txt" ]; then
    echo "vault root key doesn't yet exist" >&2
    return 1
  fi

  grep "Unseal Key ${id}" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

unseal_vault_instance() {
  local vault_instance_id="${1:-}"
  if [ -z "${vault_instance_id}" ]; then
    echo "vault instance id must be provided to unseal_vault_instance" >&2
    return 1
  fi

  # We silence the output here as its pretty verbose and we only care if it succeeds or fails here
  # (a failure will abort this script automatically).
  vault_func "${vault_instance_id}" operator unseal "$(get_vault_unseal_key 1)" >/dev/null
  vault_func "${vault_instance_id}" operator unseal "$(get_vault_unseal_key 2)" >/dev/null
  vault_func "${vault_instance_id}" operator unseal "$(get_vault_unseal_key 3)" >/dev/null
}

vault_func() {
  local vault_instance_id="${1}"
  shift 1

  local user_cmd="$@"
  local exec_opts=""

  if [ -n "${VAULT_ROOT_KEY:-}" ]; then
    local full_cmd="VAULT_TOKEN="${VAULT_ROOT_KEY}" vault ${user_cmd}"
  else
    local full_cmd="vault ${user_cmd}"
  fi

  # Check if stdin is not a terminal (so data is being piped in), if there is data we'll pass it
  # through.
  if [ ! -t 0 ]; then
    cat | kubectl exec -i -n vault "vault-${vault_instance_id}" -- sh -c "${full_cmd}"
  else
    kubectl exec -n vault "vault-${vault_instance_id}" -- sh -c "${full_cmd}"
  fi
}
