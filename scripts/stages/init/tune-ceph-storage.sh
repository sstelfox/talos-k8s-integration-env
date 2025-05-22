#!/usr/bin/env bash

set -euo pipefail

# The default

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"

source "${REPO_ROOT_DIR}/scripts/cfg/talos.sh.inc"

# This is especially important for our integration cluster as there aren't a huge number of OSDs
# leading to a health warning with too many PGs assigned to each OSD. This can be tweaked either by
# manually setting the specific values or by making use of the auto-scalar. The auto-scalar is
# enabled but suspended with a global flag by default. This clears that flag so it can do its work.
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool unset noautoscale

# Ceph health status monitoring
#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail

# Storage inspection (whole cluster and per OSD)
#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df
#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd df

# Inspect more details about the cluster's hierarchy
#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree

#kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail

# The previous commands leave a bunch of evicted containers behind, let's clean those up.
kubectl get pods -n rook-ceph --field-selector=status.phase=Failed -o json |
  kubectl delete -f - &>/dev/null
