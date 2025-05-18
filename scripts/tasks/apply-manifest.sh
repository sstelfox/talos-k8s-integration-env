#!/usr/bin/env bash

set -euo pipefail

source ./scripts/lib/manifests.sh.inc

MANIFEST_ID="${1:-}"
if [ -z "${MANIFEST_ID}" ]; then
  echo "must provide manifest id to the script" >&2
  exit 1
fi

if [ ! -d "./manifests/${MANIFEST_ID}" ]; then
  echo "provided manifest ID doesn't exist"
  exit 2
fi

manifest_apply "${MANIFEST_ID}"
