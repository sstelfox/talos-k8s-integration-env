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

# These keys are shared by the different groups with the private key stored in the repo. User
# access is controlled by granting a user's private key the ability to decrypt the appropriate
# service key. This decryption process should never write the unencrypted secret to disk for
# intermediate stages to ensure it isn't checked-in or leaked to other programs.
#
# Removal of access requires first rotating the acl keys the user had access to, followed by the
# secrets they could access using them.
ensure_acl_key_exists() {
  local key_name="${1:-}"

  if [ -z "${key_name}" ]; then
    echo 'usage: ensure_shared_key_exists KEY_NAME' 2>&1
    return 1
  fi

  return 0
}

# Users share the same identity across all environments
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

    echo 'You can omit the identity as it is the same one returned by `age-plugin-fido2-hmac -m`' >&2

    # TODO: This tool is _ok_ but it isn't polished and doesn't allow policies to be applied to
    # identities such as requiring presence, or support for authenticator attestations. Might be
    # worth actually writing and opensourcing my own...
    age-plugin-fido2-hmac -g >"secrets/identities/${KEY_USER_ID}.handle"

    cat "secrets/identities/${KEY_USER_ID}.handle" |
      grep 'public key' |
      grep -oP 'age1.*' >"secrets/identities/${KEY_USER_ID}.pub"
  fi

  # TODO: Should add public key to SOPS configuration where appropriate

  # TODO: Need to warn on any acl key the new user is supposed to have access to via humans.acl as
  # they won't be able to re-encrypt the secrets themselves. This should be done in the PR by a user
  # with at least the level of privilege required.

  return 0
}

ensure_service_key_exists() {
  local service="${1:-}"

  if [ -z "${key_name}" ]; then
    echo 'usage: ensure_service_key_exists KEY_NAME' 2>&1
    return 1
  fi

  # TODO: Should verify the user has the ability to read the service key using the contents of
  # `secrets/humans.acl`. We actually need to confirm at least one human has a public key that can
  # be used to encrypt the value, if the current user can read it back that implies they are on the
  # list of encryption recipients and ensures that users which shouldn't have access to it are
  # unable to initialize (and potentially hold onto) keys they shouldn't have access to.

  if [ ! -f "${CLUSTER_SECRET_ROOT}/${service}.key" ]; then
    mkdir -p "${CLUSTER_SECRET_ROOT}"
    PUBLIC_KEY="$(age-keygen -o "${CLUSTER_SECRET_ROOT}/${service}.key" 2>&1 | awk '{ print $3 }')"
    sops encrypt -i ${CLUSTER_SECRET_ROOT}/${service}.key

    echo "${PUBLIC_KEY}" >"${CLUSTER_SECRET_ROOT}/${service}.pub"
  fi""

  # TODO: Should ensure the SOPS configuration has this public listed matching the paths it is
  # configured to have access to via `${CLUSTER_SECRET_ROOT}/humans.acl` and

  echo "${service} public key: $(cat "${CLUSTER_SECRET_ROOT}/${service}.pub")" >&2

  return 0
}

initialize_cluster_permissions() {
  if [ -d "${CLUSTER_SECRET_ROOT}" ]; then
    return 0
  fi

  cat <<-EOF > "${CLUSTER_SECRET_ROOT}/humans.acl"
  EOF

  return 0
}

main() {
  initialize_cluster_permissions

  # During initialization its important
  ensure_current_user_key_exists

  ensure_acl_key_exists app-eng
  ensure_acl_key_exists operations
  ensure_acl_key_exists root

  ensure_service_key_exists argocd
  ensure_service_key_exists backups
}

main
