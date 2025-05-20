#!/usr/bin/env bash

set -euo pipefail

# This script expects to get run after the vault/init minimal bootstrap manifest is applied early
# on in the cluster setup. Vault requires it to be initialized and unsealed using an external
# process from the cluster which this script handles.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"
source "${REPO_ROOT_DIR}/scripts/lib/vault.sh.inc"

# We need to wait for the pods to come up. We can't rely on checking for the container to be
# "Ready" as there is a readiness check that will only succeed after the vault has been both
# initialized and unsealed.
echo "waiting for vault containers to be created..." >&2
if ! kubectl -n vault wait --for=jsonpath='{.status.phase}'=Running --all pods -l app.kubernetes.io/name=vault --timeout=90s &>/dev/null; then
  echo "timed out waiting for vault containers to reach running status" >&2
  exit 1
fi

echo "pod ready beginning vault initialization" 2>&1

# Initialize the actual vault, store the keys in our standard secrets directory
#
# These need to be protected and delegated appropriately to allow dead-man unlocks of the vault
# when automation fails. The root key should migrate to the breakglass audit access with custody
# provided by the C-suite.
#
# todo(sstelfox): this should be encrypted and we may want to capture this as part of a DR package.
mkdir -p "${SECRETS_DIR}"
vault_func 0 operator init >"${SECRETS_DIR}/vault-keys.txt"

# We need to unseal each of the instances. For the ones other than the initial one we'll need
# to join them into the cluster before we can unseal them.
unseal_vault_instance 0

vault_func 1 operator raft join http://vault-0.vault-internal:8200 &>/dev/null
unseal_vault_instance 1

vault_func 2 operator raft join http://vault-0.vault-internal:8200 &>/dev/null
unseal_vault_instance 2

# Now that the cluster is up we can set this key to begin authenticated operations to the
# kubernetes cluster to setup our environment.
VAULT_ROOT_KEY="$(get_vault_root_key)"

# We'll need the FQDN for the service in a few certificate locations
VAULT_CN="vault.vault.svc.${CLUSTER_DOMAIN}"

# With vault up we can start configuring it, I may want to switch this to something like terraform
# but this is sufficient for now. Very short intervals here to battle test rotation procedures.

# We start with the basic key/value service that will be used for general secret storage. We want
# to avoid kubernetes secrets as they don't provide nearly as detailed audit and authorization
# mechanisms.
vault_func 0 secrets enable -version=2 -path=kv kv &>/dev/null

# Enable and configure the PKI engine for the root
vault_func 0 secrets enable -path=pki_root pki &>/dev/null

# todo(sstelfox): need to configure some pretty heavy policy restrictions
# todo(sstelfox): maybe set max_path_length? permitted_ip_ranges (probably relevant to intermediate)?
# Ref: https://developer.hashicorp.com/vault/api-docs/secret/pki
vault_func 0 secrets tune -max-lease-ttl=720h pki_root &>/dev/null # 30 days for root

# Set these variables before we issue any certificates to ensure they're following best practices
# even if we're likely not going to need them in this cluster. Vault will produce a warning without
# these.
vault_func 0 write pki_root/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_root/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_root/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_root/ocsp" &>/dev/null

# Generate our actual root CA
vault_func 0 write pki_root/root/generate/internal common_name=\"Cluster Root CA\" ttl=720h \
  max_path_length=2 key_type=ec key_bits=521 &>/dev/null

# Enable and configure an intermediate CA, shorter duration little bit lower security mostly used
# here as a demonstration in case we need them to split different functions across different
# intermediates for isolation.
# todo(sstelfox): this needs to have a security tune as well, connect back to roles?
vault_func 0 secrets enable -path=pki_int_svc pki &>/dev/null
vault_func 0 secrets tune -max-lease-ttl=168h pki_int_svc &>/dev/null # 7 days for intermediate

# Before we issue certificates we need to configure some best-practice URLs as we did with the root
# CA.
vault_func 0 write pki_int_svc/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_int_svc/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_int_svc/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_int_svc/ocsp" &>/dev/null

# This one needs to be signed so we have to initially generate a new request, pull that locally,
# get it signed then push it back once its good to go.
CSR="$(vault_func 0 write -format=json pki_int_svc/intermediate/generate/internal \
  key_type=ec key_bits=384 common_name=\"Cluster Services CA\" ttl=168h \
  max_path_length=1 | jq -r '.data.csr')"

# This gets the intermediate signed by our root, we'll hold on to a copy of the resulting
# certificate bundle.
echo "${CSR}" | vault_func 0 write -format=json pki_root/root/sign-intermediate csr=- \
  format=pem_bundle ttl=168h | jq -r '.data.certificate' >"${SECRETS_DIR}/vault.int-svc-bundle.pem"

# We need to write the signed result back to the CA for it to be used
cat "${SECRETS_DIR}/vault.int-svc-bundle.pem" | vault_func 0 write pki_int_svc/intermediate/set-signed \
  certificate=- &>/dev/null

# We need to allow these specific certificates to be issued.
# todo(sstelfox): this authority can be restricted to the automated sidecars when that is setup to
#   ensure the certs aren't issued by anyone else. Need to refine this config and control
vault_func 0 write pki_int_svc/roles/vault allowed_domains="vault,vault.svc.${CLUSTER_DOMAIN}" \
  allow_bare_domains=true allow_subdomains=true max_ttl=72h &>/dev/null # 3 days for server certs

# Then issue the certificate. WARNING: This JSON file contains a private key
# todo(sstelfox): more secrets to protect and possibly include in the DR bundle
vault_func 0 write -format=json pki_int_svc/issue/vault common_name="${VAULT_CN}" \
  alt_names="vault.vault,vault" ip_sans="127.0.0.1,::1" >"${SECRETS_DIR}/vault.svc-certs.json" 2>/dev/null

# We now have the signed certificate, key, and CA bundle from Vault we need to pull the individual
# values out into files that we can put into a secret for the Vault containers to use.
mkdir -p "${SECRETS_DIR}/vault-tls"
jq -r '.data.certificate' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/tls.crt"
jq -r '.data.private_key' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/tls.key"
jq -r '.data.issuing_ca' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/ca.crt"

# And create the appropriate secret with our various files in the vault namespace
kubectl create secret generic vault-tls -n vault --from-file="${SECRETS_DIR}/vault-tls/tls.crt" \
  --from-file="${SECRETS_DIR}/vault-tls/tls.key" --from-file="${SECRETS_DIR}/vault-tls/ca.crt" &>/dev/null

# We should now have everything setup to move to the next phase of Vault bootstrapping and can go on
# from there. We'll report out our status for verification...
