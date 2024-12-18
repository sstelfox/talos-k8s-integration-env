#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

KEY_USERID="${KEY_USERID:-$(whoami)}"
if [ ! -r "secrets/identities/${KEY_USERID}.handle" ]; then
  mkdir -p secrets/identities/

  echo "You can omit the identity as it is the same one returned by $(age-plugin-fido2-hmac -m)" >&2
  age-plugin-fido2-hmac -g >"secrets/identities/${KEY_USERID}.handle"

  cat "secrets/identities/${KEY_USERID}.handle" |
    grep 'public key' |
    grep -oP 'age1.*' >"secrets/identities/${KEY_USERID}.pub"
fi

SOPS_KEY_ROOT="./secrets/${TALOS_CLUSTER_NAME}"

mkdir -p "${SOPS_KEY_ROOT}"

if [ ! -f "${SOPS_KEY_ROOT}/argocd.key" ]; then
  PUBLIC_KEY="$(age-keygen -o "${SOPS_KEY_ROOT}/argocd.key" 2>&1 | awk '{ print $3 }')"
  sops encrypt -i secrets/firmament-integration/argocd.key

  echo "${PUBLIC_KEY}" >"${SOPS_KEY_ROOT}/argocd.pub"
  echo "ArgoCD Public Key: ${PUBLIC_KEY}" >&2
fi
