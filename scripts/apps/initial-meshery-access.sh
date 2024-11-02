#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Do the dirty to extract our host's IP address
SERVER_IP=$(ip route get 1 | grep -oP 'src \K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
SERVER_PORT="9081"

kubectl port-forward --namespace meshery --address 0.0.0.0 svc/meshery ${SERVER_PORT}:9081
