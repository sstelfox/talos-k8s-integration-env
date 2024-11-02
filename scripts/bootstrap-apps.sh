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

  echo "applying ${manifest_id}..."
  if ! kubectl apply --server-side=true -f "${rendered_output}" >/dev/null; then
    echo "failed to apply ${manifest_id}"
    return 2
  fi

  echo "successfully applied ${manifest_id}"
  return 0
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

  echo "rendering ${manifest_id}..."
  if ! kubectl kustomize --enable-helm --load-restrictor LoadRestrictionsNone -o "${output_file}" ./manifests/${manifest_id} >/dev/null; then
    echo "failed to render ${manifest_id}"
    return 3
  fi

  echo "successfully rendered ${manifest_id}"
  return 0
}

mkdir -p "${RENDERED_MANIFEST_DIR}"

apply_manifest kyverno/bootstrap

# This needs work and I probably need to render out the manifest and use the job to apply it inline
# instead of using the cilium-install CI image to prevent the management transition.
#apply_manifest cilium/bootstrap

apply_manifest rook-ceph/bootstrap
apply_manifest argocd/bootstrap

# Just trying this out, haven't decided whether I want to use it or not
apply_manifest meshery/bootstrap
