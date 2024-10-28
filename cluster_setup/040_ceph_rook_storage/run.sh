#!/usr/bin/env sh

helm repo add rook-release https://charts.rook.io/release

# TODO: Customize this installation (https://rook.io/docs/rook/v1.8/ceph-cluster-crd.html)
helm install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster

kubectl --namespace rook-ceph get cephcluster
kubectl get storageclass
