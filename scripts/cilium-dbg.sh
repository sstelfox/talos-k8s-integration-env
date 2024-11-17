#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg $@
