#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

CLUSTER_SECRET_ROOT="./secrets/${TALOS_CLUSTER_NAME}"

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
    return 1
  fi

  echo "${selected_token}"
  return 0
}

IDENTITY_PATH="./secrets/identities/$(whoami).sk"

# Might be able to use ssh key backed by the token instead of age-hmac directly and  could use this
# to potentially sign commits and auth to a repo.. Nice to have it all in one place... (the answer
# is no, age can't use agent based keys or deeper authentication methods just the raw keys)
#
# Should test -O verify-required, that pin request may not work with our tokens
#ssh-keygen -t ed25520-sk -O resident -O user=$(whoami) -O device=${device from validate_fido2_tokens} -C "$(whoami) cluster key" -f ~/.ssh/cluster-key-sk-fido2
if [ ! -f "${IDENTITY_PATH}" ]; then
  TARGET_TOKEN="$(locate_valid_fido2_token)"

  # Might be able to use ssh key backed by the token instead of age-hmac directly and  could use this
  # to potentially sign commits and auth to a repo.. Nice to have it all in one place...
  #
  # Should test -O verify-required, that pin request may not work with our tokens
  mkdir -p "$(basename ${IDENTITY_PATH})"

  # The write-attestation details are VERY senstitive and should be encrypted and likely not stored
  # in the database. We don't make use of it yet, its been included for curiousity for now.
  ssh-keygen -t ed25519-sk -O resident -O user="$(whoami)" -O device="${TARGET_TOKEN}" \
    -C "$(whoami) cluster key" -O verify-required \
    -O write-attestation=./secrets/identities/$(whoami).att \
    -f "${IDENTITY_PATH}"

  # Confirm the key had a passphrase set on it
  if ssh-keygen -y -P "" -f "${IDENTITY_PATH}" &>/dev/null; then
    echo "SSH key needs to have a passphrase set on it!"
    rm -f "${IDENTITY_PATH}"
    exit 1
  fi
fi

# https://emmanuelbernard.com/blog/2023/11/27/git-signing-ssh/
# https://threatzer.com/posts/wsl-yubikeys/
# https://swjm.blog/the-complete-guide-to-ssh-with-fido2-security-keys-841063a04252
