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
  local headless_user="${2:-false}"

  if [ -z "${key_name}" ]; then
    echo 'usage: ensure_shared_key_exists KEY_NAME' 2>&1
    return 1
  fi

  if [ ! -f "${CLUSTER_SECRET_ROOT}/acl-${key_name}.enc" ]; then
    # Generate new key pair
    local acl_private_key="$(age-keygen 2>${CLUSTER_SECRET_ROOT}/acl-${key_name}.pub)"
    local acl_public_key="$(cat ${CLUSTER_SECRET_ROOT}/acl-${key_name}.pub)"

    local encrypting_key

    if [ "${headless_user}" = "true" ]; then
      encrypting_key="$(cat ./secrets/identities/headless.pub)"
    else
      encrypting_key="$(cat ./secrets/identities/${KEY_USER_ID}.pub)"
    fi

    PRIVATE_KEY="$(age-keygen 2>/dev/null)"
    PUBLIC_KEY="$(echo "${PRIVATE_KEY}" | grep 'public key:' | grep -oP 'age1.*')"

    #sops encrypt --age "${encrypting_key}" --input-type binary \
    #  --output "${CLUSTER_SECRET_ROOT}/acl-${key_name}.enc"
  fi

  return 0
}

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
    age-plugin-fido2-hmac -g >"secrets/identities/${KEY_USER_ID}.handle"

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

ensure_service_key_exists() {
  local service="${1:-}"
  local headless="${2:-}"

  if [ -z "${service}" ] || [ -z "${headless}" ]; then
    echo 'usage: ensure_service_key_exists SERVICE HEADLESS' 2>&1
    return 1
  fi

  if [ ! -f "${CLUSTER_SECRET_ROOT}/svc-${service}.enc" ]; then
    mkdir -p "${CLUSTER_SECRET_ROOT}"

    PRIVATE_KEY="$(age-keygen 2>/dev/null)"
    echo "${PRIVATE_KEY}" | grep 'public key:' | grep -oP 'age1.*'>"${CLUSTER_SECRET_ROOT}/svc-${service}.pub"

    #echo sops encrypt --age "${SERVICE_PUBLIC_KEY}" >"${CLUSTER_SECRET_ROOT}/${service}.enc"
    exit 1

    echo "${PUBLIC_KEY}" >"${CLUSTER_SECRET_ROOT}/${service}.pub"
  fi

  # TODO: Should ensure the SOPS configuration has this public listed matching the paths it is
  # configured to have access to via `${CLUSTER_SECRET_ROOT}/humans.acl` and

  echo "${service} public key: $(cat "${CLUSTER_SECRET_ROOT}/${service}.pub")" >&2

  return 0
}

initialize_cluster_permissions() {
  if [ -d "${CLUSTER_SECRET_ROOT}" ]; then
    return 0
  fi

  mkdir -p "${CLUSTER_SECRET_ROOT}/backup-seed"

  cat <<-EOF >"${CLUSTER_SECRET_ROOT}/humans.acl"
		# This file was automatically generated during cluster initialization and needs to be reviewed
		# and edited for approved access before making the cluster operational.

		# Initial user is granted the administrative roles
		${KEY_USER_ID}    root,operations
	EOF

  cat <<-EOF >"${CLUSTER_SECRET_ROOT}/automations.acl"
		# This file was automatically generated during cluster initialization and needs to be reviewed
		# and edited for approved access before making the cluster operational

		# ArgoCD needs access to all secrets in the manifest directory
		argocd                path_regex:manifests/.*/secrets\.yaml$

		# The breakglass key is equivalent to root level access but its use does not require the two-man
		# rule. The private portion of this key should not be persisted to this repo in any form. The
		# breakglass key is the only exception to the two-man rule for this level of access and MUST only
		# be used as an absolute last resort and only with explicit written executive sign-off.
		breakglass            path_regex:manifests/.*/secrets\.yaml$
		breakglass            path_regex:${CLUSTER_SECRET_ROOT}/.*\.enc$

		# This key is used for encrypting the backups needed for disaster recovery processes specific to
		# customers
		cluster-seed-backups  path_regex:${CLUSTER_SECRET_ROOT}/backup-seed/.*\.enc$
	EOF

  cat <<-EOF >"${CLUSTER_SECRET_ROOT}/roles.acl"
		# This file was automatically generated during cluster initialization and needs to be reviewed
		# and edited for approved access before making the cluster operational.

		# This role is used for extreme privileged access. Use of this role requires at least two
		# permissioned users (the keys can not be owned by the same identity). During cluster
		# initialization this requirement is waved as we only have a single administrative user
		# provisioned. The cluster is not considered ready for production until the two-man rule on these
		# keys is enforced.
		root          path_regex:manifests/.*/secrets\.yaml$
		root          path_regex:${CLUSTER_SECRET_ROOT}/.*\.enc$

		# Operations staff are allowed access to all manifest secrets as they support both infrastructure
		# and application engineer deployments.
		operations    path_regex:manifests/.*/secrets\.yaml$

		# This repo currently doesn't have any application engineer managed resources defined in it, the
		# following is left in as a placeholder until then.
		app-eng       path_regex:manifests/_reference_template/secrets\.yaml$
	EOF

  return 0
}

update_sops_config() {
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

  initialize_cluster_permissions

  if [ "${headless_user}" = "true" ]; then
    ensure_headless_user_key_exists
  else
    ensure_current_user_key_exists
  fi

  ensure_service_key_exists argocd ${headless_user}
  #ensure_service_key_exists breakglass ${headless_user}
  #ensure_service_key_exists cluster-seed-backups ${headless_user}

  #ensure_acl_key_exists root ${headless_user}
  #ensure_acl_key_exists operations ${headless_user}
  #ensure_acl_key_exists app-eng ${headless_user}

  #update_sops_config ${headless_user}

  # TODO: Need to warn on any acl key the new user is supposed to have access to according to the
  # humans.acl file, as users forget to notify someone to grant them the desired level of access.
}

main $@
