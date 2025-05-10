#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

CLUSTER_SECRET_ROOT="./secrets/${TALOS_CLUSTER_NAME}"

# Default to the current username which works well when machine usernames align with our internal
# account names, this is not universally enforced yet so we allow grandfathered usernames via an
# environment variable.
KEY_USER_ID="${KEY_USER_ID:-$(whoami)}"

ensure_current_user_key_exists() {
  if [ ! -r "secrets/identities/${KEY_USER_ID}.handle" ]; then
    echo "It seems like you're identity isn't currently configured in this repo, but we may have" >&2
    echo "misdetected your identity. We've recognized you as '${KEY_USER_ID}', if this isn't correct" >&2
    echo "you can override it by setting (and exporting) the environment variable 'KEY_USER_ID' with a" >&2
    echo "different value." >&2
    echo >&2

    read -erp "Would you like to initialize '${KEY_USER_ID}' with a new FIDO2 identity (Y/n)? " CONTINUE
    case "${CONTINUE}" in
    "" | "y" | "Y")
      echo >&2
      ;;
    "n" | "N")
      exit 0
      ;;
    *)
      echo "unknown response! bailing!" >&2
      exit 1
      ;;
    esac

    mkdir -p secrets/identities/

    echo "Great! The next step is to provision a credential with your FIDO2 token. Please make sure its" >&2
    echo "plugged in and we'll start the provisioning process. The key never leaves your device but does" >&2
    echo "require user confirmation during the process so pay attention!" >&2
    echo >&2

    echo "When prompted whether you are 'fine with having a separate identity' you should choose No." >&2
    echo "Under this use case with dedicated hardware keys for this purpose there is no privacy" >&2
    echo "concerns this remediates and the hardware identifier is required for our key audits." >&2

    # TODO: This tool is _ok_ but it isn't polished and doesn't allow policies to be applied to
    # identities such as requiring presence, or support for authenticator attestations. Might be
    # worth actually writing and opensourcing my own...
    age-plugin-fido2-hmac -a es256 -g >"secrets/identities/${KEY_USER_ID}.handle"

    cat "secrets/identities/${KEY_USER_ID}.handle" |
      grep 'public key' |
      grep -oP 'age1.*' >"secrets/identities/${KEY_USER_ID}.pub"
  fi

  return 0
}

# This function is good but needs documentation on the key, security, and when/why this is used.
ensure_headless_user_key_exists() {
  if [ ! -r "secrets/identities/headless.key" ]; then
    mkdir -p secrets/identities

    local last_umask="$(umask)"
    umask 0077

    age-keygen -o secrets/identities/headless.key &>/dev/null
    grep 'public key:' secrets/identities/headless.key |
      grep -o 'age1.*$' >secrets/identities/headless.pub

    umask "${last_umask}"
  fi

  return 0
}

# These keys are shared by the different groups with the private key stored in the repo. User
# access is controlled by granting a user's private key the ability to decrypt the appropriate
# service key. This decryption process should never write the unencrypted secret to disk for
# intermediate stages to ensure it isn't checked-in or leaked to other programs.
#
# Removal of access requires first rotating the acl keys the user had access to, followed by the
# secrets they could access using them.
ensure_key_exists() {
  local prefix="${1:-}"
  local service="${2:-}"
  local headless="${3:-}"

  if [ -z "${service}" ] || [ -z "${headless}" ]; then
    echo 'usage: ensure_key_exists TYPE SERVICE HEADLESS' 2>&1
    return 1
  fi

  if [ ! -r "${CLUSTER_SECRET_ROOT}/${prefix}-${service}.enc" ]; then
    mkdir -p "${CLUSTER_SECRET_ROOT}"

    local private_key="$(age-keygen 2>/dev/null)"
    echo "${private_key}" |
      grep 'public key:' |
      grep -oP 'age1.*'>"${CLUSTER_SECRET_ROOT}/${prefix}-${service}.pub"

    local encrypting_key
    if [ "${headless}" = "true" ]; then
      encrypting_key="$(cat ./secrets/identities/headless.pub)"
    else
      encrypting_key="$(cat ./secrets/identities/${KEY_USER_ID}.pub)"
    fi

    local last_umask="$(umask)"
    umask 0077

    # This could have been written directly above, but ideally we could pipe this value through
    # sops so the unencrypted version never touches disk. I'm going to hold out hope this is
    # possible in the future and keep it in a variable form for now.
    echo "${private_key}" > "${CLUSTER_SECRET_ROOT}/${prefix}-${service}.enc"
    #sops encrypt -i "${CLUSTER_SECRET_ROOT}/${prefix}-${service}.enc"

    umask "${last_umask}"
  fi

  echo "${prefix}-${service} public key: $(cat "${CLUSTER_SECRET_ROOT}/${prefix}-${service}.pub")" >&2

  return 0
}

initialize_cluster_permissions() {
  local headless="${1:-}"

  if [ -z "${headless}" ]; then
    echo 'usage: initialize_cluster_permissions HEADLESS' 2>&1
    return 1
  fi

  if [ -d "${CLUSTER_SECRET_ROOT}" ]; then
    return 0
  fi

  mkdir -p "${CLUSTER_SECRET_ROOT}/backup-seed"
  touch "${CLUSTER_SECRET_ROOT}/backup-seed/.gitkeep"

  local root_user
  if [ "${headless}" = "true" ]; then
    root_user="headless"
  else
    root_user="${KEY_USER_ID}"
  fi

  env ROOT_USER_ID="${root_user}" \
    envsubst <"./secrets/templates/humans.acl.template" >"${CLUSTER_SECRET_ROOT}/humans.acl"

  env CLUSTER_SECRET_ROOT="${CLUSTER_SECRET_ROOT}" \
    envsubst <"./secrets/templates/automations.acl.template" >"${CLUSTER_SECRET_ROOT}/automations.acl"

  env CLUSTER_SECRET_ROOT="${CLUSTER_SECRET_ROOT}" \
    envsubst <"./secrets/templates/roles.acl.template" >"${CLUSTER_SECRET_ROOT}/roles.acl"

  return 0
}

update_sops_config() {
  local headless="${1:-}"

  if [ -z "${headless}" ]; then
    echo 'usage: update_sops_config HEADLESS' 2>&1
    return 1
  fi

  return 0
}

main() {
  local headless_user

  # The headless user is used during integration tests in place of the current user. This is the
  # only key that is allowed to be decrypted on disk as its ephemeral, existing only for the
  # duration of the tests.
  if [ "${1:-}" = "-a" ]; then
    headless_user="true"
  else
    headless_user="false"
  fi

  initialize_cluster_permissions ${headless_user}

  if [ "${headless_user}" = "true" ]; then
    ensure_headless_user_key_exists
  else
    ensure_current_user_key_exists
  fi

  ensure_key_exists acl root ${headless_user}
  ensure_key_exists acl operations ${headless_user}
  ensure_key_exists acl app-eng ${headless_user}

  ensure_key_exists svc argocd ${headless_user}
  ensure_key_exists svc breakglass ${headless_user}
  ensure_key_exists scv cluster-seed-backup ${headless_user}

  update_sops_config ${headless_user}

  # TODO: Need to warn on any acl key the new user is supposed to have access to according to the
  # humans.acl file, as users forget to notify someone to grant them the desired level of access.
}

main $@
