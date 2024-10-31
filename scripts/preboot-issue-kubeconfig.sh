#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

talosctl kubeconfig -n 10.5.0.2 -f

kubectl get nodes
kubectl get pods -A
