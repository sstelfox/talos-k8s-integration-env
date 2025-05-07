#!/usr/bin/env bash

# This chart isn't actually published unfortunately, we do want to customize it from the default
# rendered version provided. We've chosen to not allow git submodules in this directory due to the
# complications and external nature of the dependencies in an airgapped environment.
#
# We may still end up vendoring the charts directly here to preserve them. We're ensuring the
# upstream doesn't change the version out from underneath us by pulling from a tagged release and
# validating the digest matches our expectation. This change should only occur during version
# upgrades.
#
# The way this is setup right now, changes to the values file will also download the upstream
# artifact to have the new values applied. This means that changes to the committed version of the
# manifests must happen online and should be subject to full peer review to ensure unintended
# changes do not slip in especially during version updates.
#
# If the upstream becomes unavailable we will have the most recently committed version but not the
# original templates it was generated from. This is not a terribly large chart and could be
# recreated from the rendered one if necessary.

set -euo pipefail

MANIFEST_STAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VALUES_FILE="${MANIFEST_STAGE_ROOT}/values.yaml"
if [ ! -f "${VALUES_FILE}" ]; then
  echo "unable to locate values file for manifest generation" 2>&1
  exit 1
fi

VALUES_HASH="$(sha256sum "${VALUES_FILE}" | awk '{ print $1 }')"
LAST_GENERATED_HASH=""
if [ -f "${MANIFEST_STAGE_ROOT}/.values.yaml.digest" ]; then
  LAST_GENERATED_HASH="$(cat "${MANIFEST_STAGE_ROOT}/.values.yaml.digest")"
fi

VERSION="v0.0.31"
# This needs to be populated by hand after a review, digests are not published alongside the tar
# file and we don't have signatures over the artifacts.
VERSION_DIGEST="eb79da9c759be80df4fda2b5dd689773072e94088e5cbe55002d3d6c02071564"
OUTPUT_FILE="${MANIFEST_STAGE_ROOT}/node-local-ephemeral-${VERSION}.yaml"

if [ -f "${OUTPUT_FILE}" ] && [ "${VALUES_HASH}" = "${LAST_GENERATED_HASH}" ]; then
  echo "values and version already up to date, nothing to do" 2>&1
  exit 0
fi

echo "fetching local-path-provisioner chart (${VERSION})..." 2>&1

# Create a temporary directory to download and install the repo archive to and ensure it gets
# cleaned up when we're done.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

CHART_URL="https://github.com/rancher/local-path-provisioner/archive/refs/tags/${VERSION}.tar.gz"
curl -sSL "${CHART_URL}" -o "${TMP_DIR}/chart.tar.gz"

DOWNLOADED_DIGEST="$(sha256sum "${TMP_DIR}/chart.tar.gz" | awk '{ print $1 }')"
if [ ! "${VERSION_DIGEST}" = "${DOWNLOADED_DIGEST}" ]; then
  echo "expected version digest '${VERSION_DIGEST}' but downloaded version had digest '${DOWNLOADED_DIGEST}'" 2>&1
  exit 1
fi

mkdir -p "${TMP_DIR}/extracted"
tar -xz -f "${TMP_DIR}/chart.tar.gz" -C "${TMP_DIR}/extracted"

# Perform a sanity check that the directory structure matches our expectations
export CHART_PATH="${TMP_DIR}/extracted/local-path-provisioner-${VERSION#*v}/deploy/chart/local-path-provisioner"

if [ ! -d "${CHART_PATH}" ]; then
  echo "chart not found at expected path within the repo" 2>&1
  exit 2
fi

# Render the changed / current version
CONFIGURED_NAMESPACE="$(yq -rM '.metadata.name' namespace.yaml)"
helm template local-path-provisioner "${CHART_PATH}" --namespace "${CONFIGURED_NAMESPACE}" \
  --values "${VALUES_FILE}" >"${OUTPUT_FILE}"

echo "${VALUES_HASH}" >"${MANIFEST_STAGE_ROOT}/.values.yaml.digest"
