#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

./_out/talosctl kubeconfig -n 10.5.0.2 -f

kubectl get nodes

#kubectl get pods -n kube-system -l app=cilium-install
#kubectl logs -n kube-system -l app=cilium-install

#kubectl get pods -n kube-system -l k8s-app=cilium
#kubectl get -n kube-system pod -l k8s-app=cilium -o yaml
kubectl logs -n kube-system -l k8s-app=cilium
