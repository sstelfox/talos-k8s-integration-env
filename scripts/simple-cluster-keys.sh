#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

CLUSTER_SECRET_ROOT="./secrets/${TALOS_CLUSTER_NAME}"

validate_fido2_tokens() {
  # Check if fido2-token is available
  if ! command -v fido2-token >/dev/null 2>&1; then
    echo "fido2-token command not found" >&2
    return 1
  fi

  # Get list of tokens
  tokens=$(fido2-token -L)
  if [ -z "$tokens" ]; then
    echo "no fido2 tokens found" >&2
    return 1
  fi

  valid_token_found=1

  while IFS= read -r token_line; do
    # Extract token path (everything before the colon)
    token_path=$(echo "$token_line" | cut -d: -f1-2)
    violations=0

    # Get token info
    token_info=$(fido2-token -I "$token_path")

    # Check for resident keys (rk)
    if ! echo "$token_info" | grep -q "options:.*rk"; then
      echo "token $token_path missing resident key support" >&2
      violations=$((violations + 1))
    fi

    # Check for user presence (up)
    if ! echo "$token_info" | grep -q "options:.*up"; then
      echo "token $token_path missing user presence support" >&2
      violations=$((violations + 1))
    fi

    # Check for ES256 algorithm
    if ! echo "$token_info" | grep -q "algorithms:.*es256"; then
      echo "token $token_path missing es256 algorithm support" >&2
      violations=$((violations + 1))
    fi

    # Check for FIDO 2.0 or 2.1 support
    if ! echo "$token_info" | grep -q "version strings:.*\(FIDO_2_0\|FIDO_2_1_PRE\)"; then
      echo "token $token_path missing fido 2.0/2.1 support" >&2
      violations=$((violations + 1))
    fi

    # If no violations found, echo the token path and update return status
    if [ "$violations" -eq 0 ]; then
      echo "$token_path"
      valid_token_found=0
    fi
  done <<EOF
$(echo "$tokens")
EOF

  return ${valid_token_found}
}

validate_fido2_tokens
