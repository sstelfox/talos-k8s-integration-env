#!/usr/bin/env bash

set -euo pipefail

# This script expects to get run after the vault/init minimal bootstrap manifest is applied early
# on in the cluster setup. Vault requires it to be initialized and unsealed using an external
# process from the cluster which this script handles.

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"

# We need to wait for the container to come up. We can't rely on checking for the container to be
# "Ready" as there is a readiness check that will only succeed after the vault has been both
# initialized and unsealed.
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0 -n vault --timeout=30s
echo "pod ready beginning vault initialization" 2>&1

vault_func() {
  local user_cmd="$@"
  local exec_opts=""

  if [ -n "${VAULT_ROOT_KEY:-}" ]; then
    local full_cmd="VAULT_TOKEN="${VAULT_ROOT_KEY}" vault ${user_cmd}"
  else
    local full_cmd="vault ${user_cmd}"
  fi

  # Check if stdin is not a terminal (so data is being piped in), if there is data we'll pass it
  # through.
  if [ ! -t 0 ]; then
    cat | kubectl exec -i -n vault vault-0 -- sh -c "${full_cmd}"
  else
    kubectl exec -n vault vault-0 -- sh -c "${full_cmd}"
  fi
}

# Initialize the actual vault, store the keys in our standard secrets directory
# todo(sstelfox): this should be encrypted and we may want to capture this as part of a DR package.
vault_func operator init >"${SECRETS_DIR}/vault-keys.txt"

get_root_key() {
  grep "Initial Root Token" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

get_unseal_key() {
  local id="${1:-}"
  grep "Unseal Key ${id}" "${SECRETS_DIR}/vault-keys.txt" | awk '{ print $(NF) }'
  return $?
}

# Now we need to unlock the initialized vault with the keys, we'll always use the first 3 in the
# quorum. These need to be protected and delegated appropriately to allow dead-man unlocks of the
# vault when automation fails. The root key should migrate to the breakglass audit access with
# custody provided by the C-suite.
vault_func operator unseal "$(get_unseal_key 1)"
vault_func operator unseal "$(get_unseal_key 2)"
vault_func operator unseal "$(get_unseal_key 3)"

VAULT_ROOT_KEY="$(get_root_key)"

# We'll need the FQDN for the service in a few certificate locations
VAULT_CN="vault.vault.svc.${CLUSTER_DOMAIN}"

# With vault up we can start configuring it, I may want to switch this to something like terraform
# but this is sufficient for now. Very short intervals here to battle test rotation procedures.

# Enable configure and generate a Root CA certificate
vault_func secrets enable -path=pki_root pki
vault_func secrets tune -max-lease-ttl=720h pki_root # 30 days for root
vault_func write pki_root/root/generate/internal common_name=\"Cluster Root CA\" ttl=720h
# todo(sstelfox): need to configure some pretty heavy policy restrictions

# Set these variables before we issue any certificates to ensure they're following best practices
# even if we're likely not going to need them in this cluster. Vault will produce a warning without
# these.
vault_func write pki_root/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_root/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_root/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_root/ocsp"

# The config URLs are not sufficient on their own to suppress the AIA warning, we need to extract
# its self-signed issuer ID and feed it back to the issuer config
vault_func list -format=json pki_root/issuers/ >"${SECRETS_DIR}/root_issuers.json"
ROOT_ISSUER_ID=$(jq -r '.[0]' "${SECRETS_DIR}/root_issuers.json")

# This is writing back that issuer config
vault_func write pki_root/issuer/${ROOT_ISSUER_ID} \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_root/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_root/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_root/ocsp"

# Enable and configure an intermediate CA, shorter duration little bit lower security mostly used
# here as a demonstration in case we need them to split different functions across different
# intermediates for isolation.
vault_func secrets enable -path=pki_int pki
vault_func secrets tune -max-lease-ttl=168h pki_int # 7 days for intermediate
CSR="$(vault_func write -format=json pki_int/intermediate/generate/internal \
  common_name=\"Cluster Intermediate CA\" ttl=168h | jq -r '.data.csr')"

# This gets the intermediate signed by our root, we'll hold on to a copy of the resulting
# certificate bundle.
echo "${CSR}" | vault_func write -format=json pki_root/root/sign-intermediate csr=- \
  format=pem_bundle ttl=168h | jq -r '.data.certificate' >"${SECRETS_DIR}/vault.int-ca-bundle.pem"

# We need to write the signed result back to the CA for it to be used
cat "${SECRETS_DIR}/vault.int-ca-bundle.pem" | vault_func write pki_int/intermediate/set-signed \
  certificate=-

# And now that the certificate is valid and able to issue certificates let's make sure its also
# configured correctly.
vault_func write pki_int/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_int/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_int/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_int/ocsp"

# Similar to the root CA we need to register the available issuers
vault_func list -format=json pki_int/issuers/ >"${SECRETS_DIR}/intermediate_issuers.json"
ISSUER_ID=$(jq -r '.[0]' "${SECRETS_DIR}/intermediate_issuers.json")

vault_func write pki_int/issuer/${ISSUER_ID} \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_int/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_int/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_int/ocsp"

# We need to allow these specific certificates to be issued.
# todo(sstelfox): this authority can be restricted to the automated sidecars when that is setup to
#   ensure the certs aren't issued by anyone else.
vault_func write pki_int/roles/vault allowed_domains="vault,vault.svc.${CLUSTER_DOMAIN}" \
  allow_bare_domains=true allow_subdomains=true max_ttl=72h # 3 days for server certs

# Then issue the certificate. WARNING: This JSON file contains a private key
# todo(sstelfox): more secrets to protect and possibly include in the DR bundle
vault_func write -format=json pki_int/issue/vault common_name="${VAULT_CN}" \
  alt_names="vault.vault,vault" ip_sans="127.0.0.1,::1" >"${SECRETS_DIR}/vault.svc-certs.json"
