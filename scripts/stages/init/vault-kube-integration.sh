#!/usr/bin/env bash

set -euo pipefail

# Once vault is secure and has a baseline CA, our next step in the vault integration is using a
# vault controlled certificate to manage the kubernetes node and api certificates. This won't
# actually switch the cluster over to using them as we'll need to patch the machine configs to
# switch this authority over.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/vault.sh.inc"

VAULT_ROOT_KEY="$(get_vault_root_key)"
VAULT_CN="vault.vault.svc.${CLUSTER_DOMAIN}"

## Basic Kubernetes Authentication Setup

vault_func 0 auth enable kubernetes &>/dev/null

# todo(sstelfox): configuration currently untested:
vault_func 0 write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc" \
  disable_local_ca_jwt="true"

## Kubernetes Cluster CA

# We're going to create kubernetes intermediate CA as well but we're not going to utilize it yet.
vault_func 0 secrets enable -path=pki_int_kube pki &>/dev/null
vault_func 0 secrets tune -max-lease-ttl=168h pki_int_kube &>/dev/null # 7 days for intermediate

# Configure the best practice URLs to maintain our certificate compliance
vault_func 0 write pki_int_kube/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_int_kube/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_int_kube/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_int_kube/ocsp" &>/dev/null

# Grab the CSR so we can sign this with our root
CSR="$(vault_func 0 write -format=json pki_int_kube/intermediate/generate/internal \
  key_type=ec key_bits=384 common_name=\"Cluster Kubernetes CA\" ttl=168h \
  max_path_length=1 | jq -r '.data.csr')"

# Sign with our root authority
echo "${CSR}" | vault_func 0 write -format=json pki_root/root/sign-intermediate csr=- \
  format=pem_bundle ttl=168h | jq -r '.data.certificate' >"${SECRETS_DIR}/vault.int-kube-bundle.pem"

# And write it back in so its available for our intermediate
cat "${SECRETS_DIR}/vault.int-kube-bundle.pem" | vault_func 0 write pki_int_kube/intermediate/set-signed \
  certificate=- &>/dev/null

## Enable Audit Logging

# note: not tested
#vault_func 0 audit enable file file_path=/vault/audit/audit.log format=json &>/dev/null
