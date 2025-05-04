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

if [ ! -f "${SECRETS_DIR}/vault-csv.conf" ]; then
	cat <<EOF >"${SECRETS_DIR}/vault-csr.conf"
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
IP.2 = [::1]
EOF
fi

exit 0

(
	cd "${SECRETS_DIR}"
)

openssl genrsa -out vault.key 2048
openssl req -new -key vault.key -out vault.csr -config vault-csr.conf \
	-subj "/CN=vault.vault.svc"
openssl x509 -req -in vault.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
	-out vault.crt -days 825 -sha256 -extfile vault-csr.conf -extensions v3_req

# Create k8s secret
kubectl create secret tls vault-tls \
	--cert=vault.crt \
	--key=vault.key \
	--namespace=vault

# Create CA secret for injector
kubectl create secret generic vault-injector-tls \
	--from-file=tls.crt=ca.crt \
	--from-file=tls.key=ca.key \
	--namespace=vault

# Clean up
rm -rf /tmp/vault-tls
