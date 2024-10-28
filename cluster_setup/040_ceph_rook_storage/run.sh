#!/usr/bin/env sh

helm repo add rook-release https://charts.rook.io/release

# TODO: Customize this installation (https://rook.io/docs/rook/v1.8/ceph-cluster-crd.html)
helm install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster

# This should be done before installing the operator, but the operator creates the namespace. There
# is probably a way to inject this as a YAML config into the operator installation but I need to
# identify that.
kubectl label ns rook-ceph pod-security.kubernetes.io/enforce=privileged

kubectl --namespace rook-ceph get cephcluster

kubectl get storageclass
