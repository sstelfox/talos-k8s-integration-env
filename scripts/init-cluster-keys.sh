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

ensure_headless_user_key_exists() {
  if [ ! -r "secrets/identities/headless.key" ]; then
    mkdir -p secrets/identities

    local last_umask="$(umask)"
    umask 0077

    PUBLIC_KEY="$(age-keygen -o secrets/identities/headless.key 2>&1)"
    echo "${PUBLIC_KEY}" | grep -oP 'age1.*' >"secrets/identities/headless.pub"

    umask "${last_umask}"
  fi

  return 0
}

ensure_service_key_exists() {
  local service="${1:-}"
  local headless_user="${2:-}"

  if [ -z "${service}" ]; then
    echo 'usage: ensure_service_key_exists SERVICE' 2>&1
    return 1
  fi

  # TODO: Should verify the user has the ability to read the service key using the contents of
  # `secrets/humans.acl`. We actually need to confirm at least one human has a public key that can
  # be used to encrypt the value, if the current user can read it back that implies they are on the
  # list of encryption recipients and ensures that users which shouldn't have access to it are
  # unable to initialize (and potentially hold onto) keys they shouldn't have access to.

  if [ ! -f "${CLUSTER_SECRET_ROOT}/${service}.enc" ]; then
    mkdir -p "${CLUSTER_SECRET_ROOT}"

    SERVICE_PRIVATE_KEY="$(age-keygen 2>"${CLUSTER_SECRET_ROOT}/${service}.pub")"
    SERVICE_PUBLIC_KEY="$(cat "${CLUSTER_SECRET_ROOT}/${service}.pub")"

    echo sops encrypt --age "${SERVICE_PUBLIC_KEY}" >"${CLUSTER_SECRET_ROOT}/${service}.enc"
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
  local include_headless="${1:-false}"

  # This script assumes its being run from the root of the repo
  # TODO: Need to include service keys
  # TODO Need to read in service public keys once they've been created
  # TODO: Need to populate the config based on the various acl files

  cat <<-EOF >.sops.yaml
# YAML references are used here to make the format a easier to audit, manage, and maintain. SOPS
# doesn't support specifying multiple AGE public keys with a list... They need to be comma
# delimited strings but at least ignores whitespace sufficiently we can put them on different
# lines.
#
# These groups and references are managed and maintained automatically.

# Application engineers: For private applications running on the cluster that are managed by less
# privileged users, this group only has access to non-infrastructure manifest secrets.
x-app-eng: &
  manifest-keys >-
EOF

  age1a5344plx2p7ar9f2xg4ewmkxn0sppqqm633cafth20kgxtefpeyqgm9fa3,
  age1g3h5t4vlvqfgwdlaqqwrkss2sjzp0uy9fw2cfufrgekjdm6gk44qdc90az

  # Operations: Needs access to secrets existing in all manifests. The users primarily manage
  # infrastructure manifests but support application engineers.
  x-operations: &
  operations-keys >-
  age1a5344plx2p7ar9f2xg4ewmkxn0sppqqm633cafth20kgxtefpeyqgm9fa3,
  age1g3h5t4vlvqfgwdlaqqwrkss2sjzp0uy9fw2cfufrgekjdm6gk44qdc90az

  # Root: Ultimate keys to the kingdom. Sensitive material protected with these keys should only be
  # needed during cluster initialization and during any disaster recovery event. This include
  # sensitive information such as the Vault root unsealing key, copies of private keys for the other
  # services present here. Unauthorized access to this requires rotating all key material in the
  # cluster.
  x-root-keys: &
  root-keys >-
  age1a5344plx2p7ar9f2xg4ewmkxn0sppqqm633cafth20kgxtefpeyqgm9fa3

  # * Ensure most specific paths are specified in this file before less specific ones
  # * Provide the minimum access necessary for each key, keys are cheap and easy to manage. Rotating
  #   many credentials is less fun.
  creation_rules:
  # Placeholder for app-engine only manifests, each individual app engineer protected file should
  # be specified in a dedicated entry. In the future we may want to get more granular with this
  # targeting specific users.
  - path_regex: manifests/_reference_template/secrets\.yaml$
  age: *app-eng-keys

  # Rule for general manifest secrets, needs to be accessible by anyone writing secrets. If there
  # was a large team working with these it would be worth getting more fine grained with the access
  # grouping here based on responsibilities.
  - path_regex: manifests/.*/secrets\.yaml$
  age: *operations-keys

  # These are encrypted copies of the private keys used by the automated services specified
  # elsewhere in this file (such as the ArgoCD keys). These should only need to be retrieved during
  # cluster initialization and during a DR event. The keys can be rotated without having access.
  - path_regex: secrets/.*/.*\.key$
  age: *root-keys
  EOF

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
  ensure_service_key_exists breakglass ${headless_user}
  ensure_service_key_exists cluster-seed-backups ${headless_user}

  #ensure_acl_key_exists root ${headless_user}
  #ensure_acl_key_exists operations ${headless_user}
  #ensure_acl_key_exists app-eng ${headless_user}

  #update_sops_config ${headless_user}

  # TODO: Need to warn on any acl key the new user is supposed to have access to according to the
  # humans.acl file, as users forget to notify someone to grant them the desired level of access.
}

main $@
