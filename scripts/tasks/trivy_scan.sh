#!/usr/bin/env bash

set -euo pipefail

./_out/trivy k8s --report=all --node-collector-namespace kube-system \
  --tolerations node-role.kubernetes.io/control-plane=:NoSchedule \
  --output ./_out/trivy-report.txt
