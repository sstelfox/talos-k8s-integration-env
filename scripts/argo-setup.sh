#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

INITIAL_ARGOCD_ADMIN_PW="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

# Do the dirty to extract our host's IP address
SERVER_IP=$(ip route get 1 | grep -oP 'src \K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
SERVER_PORT="8080"

echo "The initial account credentials for ArgoCD are:"
echo -e "\tUsername:\tadmin"
echo -e "\tPassword:\t${INITIAL_ARGOCD_ADMIN_PW}"

echo "The admin interface will be available on at https://${SERVER_IP}:${SERVER_PORT}"
echo "Press any key when you're ready to port-forward the admin interface..."
read

kubectl port-forward svc/argocd-server --address 0.0.0.0 -n argocd ${SERVER_PORT}:443
