#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Do the dirty to extract our host's IP address
SERVER_IP=$(ip route get 1 | grep -oP 'src \K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
SERVER_PORT="8000"

kubectl port-forward --namespace kube-system --address 0.0.0.0 svc/hubble-ui ${SERVER_PORT}:80
