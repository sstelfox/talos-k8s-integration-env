#!/usr/bin/env false

MANIFEST_RENDERED_DIR="./_out/manifests"

manifest_apply() {
  local manifest_id="${1:-}"

  if [ -z "${manifest_id}" ]; then
    echo 'usage: render_manifest MANIFEST_ID' >&2
    return 1
  fi

  manifest_render "${manifest_id}"

  echo "applying ${manifest_id}..." >&2

  if ! kubectl apply --server-side=true -f "$(manifest_output_file "${manifest_id}")" >/dev/null; then
    echo "failed to apply ${manifest_id}" >&2
    return 2
  fi

  echo "successfully applied ${manifest_id}" >&2
  return 0
}

manifest_output_file() {
  local manifest_id="${1:-}"

  if [ -z "${manifest_id}" ]; then
    echo 'usage: manifest_output_file MANIFEST_ID' >&2
    return 1
  fi

  echo "${MANIFEST_RENDERED_DIR}/$(echo "${manifest_id}" | sed 's#/#-#g').yaml"
}

manifest_render() {
  local manifest_id="${1:-}"

  if [ -z "${manifest_id}" ]; then
    echo "usage: render_manifest MANIFEST_ID" 2>&1
    return 1
  fi

  if [ ! -f "./manifests/${manifest_id}/kustomization.yaml" ]; then
    echo "manifest ID must point at directory containing kustomization file" 2>&1
    return 2
  fi

  echo "rendering ${manifest_id}..."
  mkdir -p "${MANIFEST_RENDERED_DIR}"

  if ! kubectl kustomize --enable-helm --load-restrictor LoadRestrictionsNone -o "$(manifest_output_file "${manifest_id}")" ./manifests/${manifest_id} >/dev/null; then
    echo "failed to render ${manifest_id}" 2>&1
    return 3
  fi

  echo "successfully rendered ${manifest_id}" 2>&1
  return 0
}
