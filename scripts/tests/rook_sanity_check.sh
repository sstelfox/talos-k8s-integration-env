#!/usr/bin/env sh

kubectl --namespace rook-ceph get cephcluster rook-ceph

kubectl get storageclass
