#!/usr/bin/env bash

set -euo pipefail

SECRETS_DIR="./_out/secrets/vault-tls"

source ./scripts/cfg/talos.sh.inc

mkdir -p "${SECRETS_DIR}"

if [ ! -f "${SECRETS_DIR}/ca.key" ]; then
  openssl genrsa -out "${SECRETS_DIR}/ca.key" 2048
fi

if [ ! -f "${SECRETS_DIR}/ca.crt" ]; then
  openssl req -x509 -new -nodes -key "${SECRETS_DIR}/ca.key" -sha256 -days 1825 \
    -out "${SECRETS_DIR}/ca.crt" -subj "/CN=vault-ca"
fi

if [ ! -f "${SECRETS_DIR}/vault-tls-base.conf" ]; then
  cat <<EOF >"${SECRETS_DIR}/vault-tls-base.conf"
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = vault
DNS.2 = vault.vault
DNS.3 = vault.vault.svc
DNS.4 = vault.vault.svc.${CLUSTER_DOMAIN}
DNS.5 = *.vault.svc.${CLUSTER_DOMAIN}
DNS.6 = localhost
IP.1 = 127.0.0.1
IP.2 = 0:0:0:0:0:0:0:1
EOF
fi

if [ ! -f "${SECRETS_DIR}/vault.key" ]; then
  openssl genrsa -out "${SECRETS_DIR}/vault.key" 2048
fi

if [ ! -f "${SECRETS_DIR}/vault.crt" ]; then
  # We only care about the CSR when generating the certificate. We want to make sure we clean this
  # up at the end so future versions will generate a fresh request.
  if [ ! -f "${SECRETS_DIR}/vault.csr" ]; then
    openssl req -new -key "${SECRETS_DIR}/vault.key" -out "${SECRETS_DIR}/vault.csr" \
      -config "${SECRETS_DIR}/vault-tls-base.conf" -subj "/CN=vault.vault.svc"
  fi

  # Good for a year and a month, todo should drop this down
  openssl x509 -req -in "${SECRETS_DIR}/vault.csr" -CA "${SECRETS_DIR}/ca.crt" \
    -CAkey "${SECRETS_DIR}/ca.key" -CAcreateserial -out "${SECRETS_DIR}/vault.crt" -days 395 \
    -sha256 -extfile "${SECRETS_DIR}/vault-tls-base.conf" -extensions v3_req

  rm -f "${SECRETS_DIR}/vault.csr"
fi

# Kind of a dirty hack but we need to ensure the namespace exists before we create the secrets...
kubectl apply -f manifests/vault/base/namespace.yaml

# Used by standard service
kubectl create secret tls vault-tls --namespace=vault --cert="${SECRETS_DIR}/vault.crt" --key="${SECRETS_DIR}/vault.key"

# Used by secret injector service
kubectl create secret generic vault-injector-tls --namespace=vault \
  --from-file=tls.crt="${SECRETS_DIR}/ca.crt" --from-file=tls.key="${SECRETS_DIR}/ca.key"
