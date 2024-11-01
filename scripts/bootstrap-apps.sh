#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Before this can run we expect at a minimum a working network within the cluster

RENDERED_MANIFEST_DIR="./_out/manifests"

apply_manifest() {
  local manifest_id="${1:-}"

  if [ -z "${manifest_id}" ]; then
    echo 'usage: render_manifest MANIFEST_ID'
    return 1
  fi

  local rendered_output="${RENDERED_MANIFEST_DIR}/$(echo "${manifest_id}" | sed 's#/#-#g').yaml"

  render_manifest "${manifest_id}" "${rendered_output}"

  kubectl apply --server-side=true -f "${rendered_output}"
}

render_manifest() {
  local manifest_id="${1:-}"
  local output_file="${2:-}"

  if [ -z "${manifest_id}" ] || [ -z "${output_file}" ]; then
    echo 'usage: render_manifest MANIFEST_ID OUTPUT_FILE'
    return 1
  fi

  if [ ! -f "./manifests/${manifest_id}/kustomization.yaml" ]; then
    echo 'manifest ID must point at directory containing kustomization file'
    return 2
  fi

  kubectl kustomize --enable-helm --load-restrictor LoadRestrictionsNone \
    -o "${output_file}" ./manifests/${manifest_id}
}

mkdir -p "${RENDERED_MANIFEST_DIR}"

apply_manifest kyverno/bootstrap