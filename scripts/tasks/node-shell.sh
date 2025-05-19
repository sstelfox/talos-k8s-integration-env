#!/usr/bin/env bash

set -euo pipefail

kubectl debug -n kube-system node/firmament-integration-worker-1 -it --profile=general \
  --image=docker.io/library/busybox:latest --
