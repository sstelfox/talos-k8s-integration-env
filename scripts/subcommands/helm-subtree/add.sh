#!/usr/bin/env bash

set -euo pipefail

# Create a temporary file and set up a trap for cleanup
TMP_FILE=$(mktemp)
trap 'rm -f "${TMP_FILE}"' EXIT INT TERM

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"
CONFIG_FILE="${REPO_ROOT_DIR}/.helm-subtree.yaml"

if ! command -v yq &>/dev/null; then
  echo "error: yq is required but not installed." >&2
  exit 1
fi

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <name> <upstream_repo> <ref> <upstream_path> [local_path]" >&2
  echo >&2
  echo "  name          - A unique name for this chart" >&2
  echo "  upstream_repo - URL of the git repository containing the chart" >&2
  echo "  ref           - Git reference (branch, tag, commit) to use" >&2
  echo "  upstream_path - Path to the chart within the upstream repo" >&2
  echo "  local_path    - Local path where the chart should be vendored (optional, defaults to charts/vendored/<name>)" >&2
  exit 1
fi

NAME="$1"
UPSTREAM_REPO="$2"
REF="$3"
UPSTREAM_PATH="$4"
LOCAL_PATH="$5"
TRACKING_BRANCH="vendored-$NAME-history"

# Remove the trailing slash from UPSTREAM_PATH if it exists
UPSTREAM_PATH="${UPSTREAM_PATH%/}"

# Don't clobber existing paths
if [ -d "${LOCAL_PATH}" ]; then
  echo "local path already exists" >&2
fi

# Create config file if it doesn't exist
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "charts: {}" >"${CONFIG_FILE}"
fi

CHART_EXISTS=$(yq -y ".charts.\"${NAME}\" | length > 0" "${CONFIG_FILE}" 2>/dev/null || echo "false")
if [ "${CHART_EXISTS}" = "true" ]; then
  echo "error: chart '${NAME}' already exists in config." >&2
  exit 1
fi

REMOTE_NAME="upstream-${NAME}"
if ! git remote | grep -q "${REMOTE_NAME}"; then
  echo "adding remote '${REMOTE_NAME}'..." >&2
  git remote add "${REMOTE_NAME}" "${UPSTREAM_REPO}"
fi

echo "fetching from upstream..." >&2
git fetch "${REMOTE_NAME}" "${REF}"

echo "setting up tracking branch..." >&2
# Handle both tags and branches by using FETCH_HEAD
git checkout -B "${TRACKING_BRANCH}" FETCH_HEAD

if ! git ls-tree -d "${TRACKING_BRANCH}:${UPSTREAM_PATH}" &>/dev/null; then
  echo "error: upstream path '${UPSTREAM_PATH}' not found in repository." >&2
  git checkout -
  exit 1
fi

cd "${REPO_ROOT_DIR}"
echo "creating subtree in ${LOCAL_PATH}..." >&2

git checkout -
mkdir -p "${LOCAL_PATH}"
git archive "${TRACKING_BRANCH}" "${UPSTREAM_PATH}" | tar -x -C "${LOCAL_PATH}" --strip-components="$(echo "${UPSTREAM_PATH%/}" | tr '/' '\n' | wc -l)"

echo "adding chart '${NAME}' to config" >&2

# Ensure charts key exists
yq -y ".charts |= (. // {})" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"

# Add chart properties
yq -y ".charts.\"${NAME}\".path = \"${LOCAL_PATH}\"" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"
yq -y ".charts.\"${NAME}\".upstream_repo = \"${UPSTREAM_REPO}\"" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"
yq -y ".charts.\"${NAME}\".upstream_path = \"${UPSTREAM_PATH}\"" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"
yq -y ".charts.\"${NAME}\".ref = \"${REF}\"" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"
yq -y ".charts.\"${NAME}\".tracking_branch = \"${TRACKING_BRANCH}\"" "${CONFIG_FILE}" >"${TMP_FILE}" && mv "${TMP_FILE}" "${CONFIG_FILE}"
git add "${LOCAL_PATH}" .helm-subtree.yaml

# This is specific to my environment, some of these upstream charts don't hold to the same
# standards...
export OVERRIDE_PRECOMMIT=true
git commit -m "vendored chart '${NAME}' from ${UPSTREAM_REPO} at ${REF}"

echo >&2
echo "successfully added chart '${NAME}'" >&2
