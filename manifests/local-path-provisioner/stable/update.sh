#!/bin/bash

set -euo pipefail

# Update this to a released tag and run it to update to a new version
VERSION="v0.0.31"

BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUTPUT_FILE="${BASE_DIRECTORY}/local-path-provisioner-manifests.yaml"
VALUES_FILE="${BASE_DIRECTORY}/values.yaml"

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -v | --version)
    VERSION="$2"
    shift 2
    ;;
  -f | --values)
    VALUES_FILE="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [-v|--version VERSION] [-f|--values VALUES_FILE]"
    exit 1
    ;;
  esac
done

echo "Fetching local-path-provisioner chart (${VERSION})..."

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

CHART_URL="https://github.com/rancher/local-path-provisioner/archive/refs/tags/${VERSION}.tar.gz"
curl -sSL "${CHART_URL}" | tar -xz -C $TEMP_DIR

EXTRACTED_DIR=$(find "${TEMP_DIR}" -type d -name "local-path-provisioner*" | head -n 1)
CHART_PATH="${EXTRACTED_DIR}/deploy/chart/local-path-provisioner"

if [ ! -d "${CHART_PATH}" ]; then
  echo "Chart not found at expected path: ${CHART_PATH}"
  exit 1
fi

#HELM_CMD="helm template local-path-provisioner ${CHART_PATH} --namespace talos-state-local-path-storage"
HELM_CMD="helm template local-path-provisioner ${CHART_PATH} --namespace kube-system"

if [ -n "${VALUES_FILE}" ]; then
  if [ ! -f "${VALUES_FILE}" ]; then
    echo "Values file not found: ${VALUES_FILE}"
    exit 1
  fi

  HELM_CMD="${HELM_CMD} --values ${VALUES_FILE}"
fi

eval "${HELM_CMD}" >"${OUTPUT_FILE}"
echo "Chart templated to ${OUTPUT_FILE}"
