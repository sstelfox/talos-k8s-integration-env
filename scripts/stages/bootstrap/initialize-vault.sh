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
mkdir -p "${SECRETS_DIR}"
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
#
# We silence the output here as its pretty verbose and we only care if it succeeds or fails here (a
# failure will abort this script automatically).
vault_func operator unseal "$(get_unseal_key 1)" >/dev/null
vault_func operator unseal "$(get_unseal_key 2)" >/dev/null
vault_func operator unseal "$(get_unseal_key 3)" >/dev/null

VAULT_ROOT_KEY="$(get_root_key)"

# We'll need the FQDN for the service in a few certificate locations
VAULT_CN="vault.vault.svc.${CLUSTER_DOMAIN}"

# With vault up we can start configuring it, I may want to switch this to something like terraform
# but this is sufficient for now. Very short intervals here to battle test rotation procedures.

# Enable and configure the PKI engine for the root
vault_func secrets enable -path=pki_root pki
# todo(sstelfox): need to configure some pretty heavy policy restrictions
# todo(sstelfox): maybe set max_path_length? permitted_ip_ranges (probably relevant to intermediate)?
# Ref: https://developer.hashicorp.com/vault/api-docs/secret/pki
vault_func secrets tune -max-lease-ttl=720h pki_root # 30 days for root

# Set these variables before we issue any certificates to ensure they're following best practices
# even if we're likely not going to need them in this cluster. Vault will produce a warning without
# these.
vault_func write pki_root/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_root/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_root/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_root/ocsp"

# Generate our actual root CA
vault_func write pki_root/root/generate/internal common_name=\"Cluster Root CA\" ttl=720h \
  max_path_length=2 key_type=ec key_bits=521

# Enable and configure an intermediate CA, shorter duration little bit lower security mostly used
# here as a demonstration in case we need them to split different functions across different
# intermediates for isolation.
# todo(sstelfox): this needs to have a security tune as well, connect back to roles?
vault_func secrets enable -path=pki_int_svc pki >/dev/null
vault_func secrets tune -max-lease-ttl=168h pki_int_svc >/dev/null # 7 days for intermediate

# Before we issue certificates we need to configure some best-practice URLs as we did with the root
# CA.
vault_func write pki_int_svc/config/urls \
  crl_distribution_points="https://${VAULT_CN}:8200/v1/pki_int_svc/crl" \
  issuing_certificates="https://${VAULT_CN}:8200/v1/pki_int_svc/ca" \
  ocsp_servers="https://${VAULT_CN}:8200/v1/pki_int_svc/ocsp"

# This one needs to be signed so we have to initially generate a new request, pull that locally,
# get it signed then push it back once its good to go.
CSR="$(vault_func write -format=json pki_int_svc/intermediate/generate/internal \
  key_type=ec key_bits=384 common_name=\"Cluster Services CA\" ttl=168h \
  max_path_length=1 | jq -r '.data.csr')"

# This gets the intermediate signed by our root, we'll hold on to a copy of the resulting
# certificate bundle.
echo "${CSR}" | vault_func write -format=json pki_root/root/sign-intermediate csr=- \
  format=pem_bundle ttl=168h |
  jq -r '.data.certificate' >"${SECRETS_DIR}/vault.int-svc-bundle.pem"

# We need to write the signed result back to the CA for it to be used
cat "${SECRETS_DIR}/vault.int-svc-bundle.pem" | vault_func write pki_int_svc/intermediate/set-signed \
  certificate=-

# We need to allow these specific certificates to be issued.
# todo(sstelfox): this authority can be restricted to the automated sidecars when that is setup to
#   ensure the certs aren't issued by anyone else. Need to refine this config and control
vault_func write pki_int_svc/roles/vault allowed_domains="vault,vault.svc.${CLUSTER_DOMAIN}" \
  allow_bare_domains=true allow_subdomains=true max_ttl=72h # 3 days for server certs

# Then issue the certificate. WARNING: This JSON file contains a private key
# todo(sstelfox): more secrets to protect and possibly include in the DR bundle
vault_func write -format=json pki_int_svc/issue/vault common_name="${VAULT_CN}" \
  alt_names="vault.vault,vault" ip_sans="127.0.0.1,::1" >"${SECRETS_DIR}/vault.svc-certs.json"

# We now have the signed certificate, key, and CA bundle from Vault we need to pull the individual
# values out into files that we can put into a secret for the Vault containers to use.
mkdir -p "${SECRETS_DIR}/vault-tls"
jq -r '.data.certificate' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/tls.crt"
jq -r '.data.private_key' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/tls.key"
jq -r '.data.issuing_ca' "${SECRETS_DIR}/vault.svc-certs.json" >"${SECRETS_DIR}/vault-tls/ca.crt"

# And create the appropriate secret with our various files in the vault namespace
kubectl create secret generic vault-tls -n vault --from-file="${SECRETS_DIR}/vault-tls/tls.crt" \
  --from-file="${SECRETS_DIR}/vault-tls/tls.key" --from-file="${SECRETS_DIR}/vault-tls/ca.crt"

# We should now have everything setup to move to the next phase of Vault bootstrapping and can go on
# from there.
