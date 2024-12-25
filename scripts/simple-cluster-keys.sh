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

IDENTITY_PATH="./secrets/identities/${KEY_USER_ID}.sk"

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

    echo "Great! The next step is to provision a credential with your FIDO2 token. Please make sure its" >&2
    echo "plugged in and we'll start the provisioning process. The key never leaves your device but does" >&2
    echo "require user confirmation during the process so pay attention!" >&2
    echo >&2

    echo "When prompted whether you are 'fine with having a separate identity' you should choose No." >&2
    echo "Under this use case with dedicated hardware keys for this purpose there is no privacy" >&2
    echo "concerns this remediates and the hardware identifier is required for our key audits." >&2
    echo >&2

    echo "We're going to do a quick check to make sure you have a compatible device connected..." >&2

    # TODO: Loop until the user connects at least one device...
    TARGET_TOKEN="$(locate_valid_fido2_token)"
    echo "We can't specify which token to age unfortunately. Most likely the selected one will" >&2
    echo "be chosen but the process should work regardless." >&2

    mkdir -p secrets/identities/

    # TODO: This tool is _ok_ but it isn't polished and doesn't allow policies to be applied to
    # identities such as requiring presence, or support for authenticator attestations. Might be
    # worth actually writing and opensourcing my own...
    age-plugin-fido2-hmac -a es256 -g 2>/dev/null >"secrets/identities/${KEY_USER_ID}.handle"

    cat "secrets/identities/${KEY_USER_ID}.handle" |
      grep 'public key' |
      grep -oP 'age1.*' >"secrets/identities/${KEY_USER_ID}.pub"
  fi

  return 0
}

locate_valid_fido2_token() {
  # Ensure we can perform these sanity checks
  if ! command -v fido2-token >/dev/null 2>&1; then
    echo "fido2-token command not found" >&2
    return 1
  fi

  tokens="$(fido2-token -L)"
  if [ -z "$tokens" ]; then
    echo "no fido2 tokens found" >&2
    return 1
  fi

  local selected_token
  local valid_tokens_found=0

  while IFS= read -r token_line; do
    local token_path="$(echo "${token_line}" | sed 's/\([^:]*\): .*/\1/')"
    local token_info="$(fido2-token -I "$token_path")"
    local violations=""

    # Confirm the device supports resident keys
    if ! echo "${token_info}" | grep -q "options:.*rk"; then
      violations="no-resident-key"
    fi

    # Confirm we can confirm a user is present when we try and use the key
    if ! echo "${token_info}" | grep -q "options:.*up"; then
      if [ -n "${violations:-}" ]; then
        violations="${violations},"
      fi

      violations="${violations}no-user-presence"
    fi

    # The device must support our chosen algorithm
    if ! echo "${token_info}" | grep -q "algorithms:.*es256"; then
      if [ -n "${violations:-}" ]; then
        violations="${violations},"
      fi

      violations="${violations}missing-algorithm"
    fi

    # The device must be new enough to support at least FIDO2
    if ! echo "${token_info}" | grep -q "version strings:.*\(FIDO_2_0\|FIDO_2_1_PRE\)"; then
      if [ -n "${violations:-}" ]; then
        violations="${violations},"
      fi

      violations="${violations}no-fido2-support"
    fi

    if [ -n "${violations:-}" ]; then
      echo "candidate key ${token_path} has policy violations: ${violations}" >&2
    elif [ -z "${selected_token:-}" ]; then
      echo "selecting candidate key ${token_path}" >&2
      selected_token="${token_path}"
    fi
  done <<EOF
$(echo "$tokens")
EOF

  if [ -z "${selected_token}" ]; then
    echo "failed to locate valid candidate key" >&2
    return 2
  fi

  echo "${selected_token}"
  return 0
}

# Persuing ssh keys here for protecting the secrets would have been a nice benefit, it binds our
# authentication, signing, and decryption into a single key to manage per identity. We can still
# make this work with an age key backed by a fido token and a separate SSH key backed by a token.
#
# https://emmanuelbernard.com/blog/2023/11/27/git-signing-ssh/
# https://threatzer.com/posts/wsl-yubikeys/
# https://swjm.blog/the-complete-guide-to-ssh-with-fido2-security-keys-841063a04252
#if [ ! -f "${IDENTITY_PATH}" ]; then
#  TARGET_TOKEN="$(locate_valid_fido2_token)"
#
#  # Might be able to use ssh key backed by the token instead of age-hmac directly and  could use this
#  # to potentially sign commits and auth to a repo.. Nice to have it all in one place...
#  #
#  # Should test -O verify-required, that pin request may not work with our tokens
#  mkdir -p "$(basename ${IDENTITY_PATH})"
#
#  # The write-attestation details are VERY senstitive and should be encrypted and likely not stored
#  # in the database. We don't make use of it yet, its been included for curiousity for now.
#  ssh-keygen -t ed25519-sk -O resident -O user="$(whoami)" -O device="${TARGET_TOKEN}" \
#    -C "$(whoami) cluster key" -O verify-required \
#    -O write-attestation=./secrets/identities/$(whoami).att \
#    -f "${IDENTITY_PATH}"
#
#  # Confirm the key had a passphrase set on it
#  if ssh-keygen -y -P "" -f "${IDENTITY_PATH}" &>/dev/null; then
#    echo "SSH key needs to have a passphrase set on it!"
#    rm -f "${IDENTITY_PATH}"
#    exit 1
#  fi
#fi

main() {
  ensure_current_user_key_exists
  return 0
}

main "$@"
