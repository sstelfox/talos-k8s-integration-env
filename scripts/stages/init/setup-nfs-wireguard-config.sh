#!/usr/bin/env bash

set -euo pipefail

# This script creates the vault policies and configuration to support the wireguard-nfs-volumes
# manifest.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/vault.sh.inc"

INTERNAL_CLIENT_ADDR="172.16.75.177/24"
ALLOWED_WG_IPS="172.16.75.0/24"
REMOTE_ENDPOINT="10.100.50.60:51820"
REMOTE_PUBLIC_KEY="RrM1vh/eRKLUvLqop9+AhugI7d0H7nqSLzm7DgBF/2Q="

if [ -f "${SECRETS_DIR}/nfs-wireguard.key)" ]; then
  WG_PRIVATE_KEY="$(cat "${SECRETS_DIR}/nfs-wireguard.key")"
else
  WG_PRIVATE_KEY="$(wg genkey | tee "${SECRETS_DIR}/nfs-wireguard.key")"
fi

WG_PUBLIC_KEY="$(echo "${WG_PRIVATE_KEY}" | wg pubkey | tee "${SECRETS_DIR}/nfs-wireguard.pub")"

if [ -f "${SECRETS_DIR}/nfs-wireguard.secret" ]; then
  WG_SHARED_KEY="$(cat "${SECRETS_DIR}/nfs-wireguard.secret")"
else
  WG_SHARED_KEY="$(wg genpsk | tee "${SECRETS_DIR}/nfs-wireguard.secret")"
fi

WG_CONFIG="[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = ${INTERNAL_CLIENT_ADDR}

[Peer]
PublicKey = ${REMOTE_PUBLIC_KEY}
PresharedKey = ${WG_SHARED_KEY}
Endpoint = ${REMOTE_ENDPOINT}
AllowedIPs = ${ALLOWED_WG_IPS}
PersistentKeepalive = 25"

vault_func 0 kv put kv/wireguard/config wg0.conf="${WG_CONFIG}"

cat <<EOF | vault_func 0 policy write wireguard-policy -
path "kv/data/wireguard/config" {
  capabilities = ["read"]
}

path "kv/metadata/wireguard/config" {
  capabilities = ["read"]
}
EOF

vault_func 0 write auth/kubernetes/role/wireguard \
  bound_service_account_names=nfs-wireguard-gw \
  bound_service_account_namespaces=nfs-wireguard \
  policies=wireguard-policy \
  ttl=24h
