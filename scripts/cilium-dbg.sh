#!/usr/bin/env sh

set -o errexit

kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
