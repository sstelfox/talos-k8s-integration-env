#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

NODE_TYPE="${1:-}"
NODE_ID="${2:-}"

# Hard-coded as this is my bare metal integration test system that uses qemu
CLUSTER_NAME="firmament-integration"

# Default to controller logs
if [ -z "${NODE_TYPE}" ]; then
  NODE_TYPE="controlplane"
fi

# Default to the first of the specified type
if [ -z "${NODE_ID}" ]; then
  NODE_ID="1"
fi

if [ "${NODE_TYPE}" != "controlplane" ] && [ "${NODE_TYPE}" != "worker" ]; then
  echo "usage: ${0} [controlplane|worker] [node-id]"
  exit 1
fi

tail -F ${HOME}/.talos/clusters/${CLUSTER_NAME}/${CLUSTER_NAME}-${NODE_TYPE}-${NODE_ID}.log
