#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/lib/services.sh.inc

HUBBLE_CMD="hubble observe --follow ${@}"

cmd_with_k8s_port_forward kube-system hubble-relay 4245:80 "${HUBBLE_CMD}"
