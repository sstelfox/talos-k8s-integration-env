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
    echo "usage: render_manifest MANIFEST_ID" >&2
    return 1
  fi

  if [ ! -f "./manifests/${manifest_id}/kustomization.yaml" ]; then
    echo "manifest ID must point at directory containing kustomization file" >&2
    return 2
  fi

  echo "rendering ${manifest_id}..."

  local manifest_output_file="$(manifest_output_file "${manifest_id}")"
  mkdir -p "$(dirname "${manifest_output_file}")"

  # We add the --load-restrictor flag here to allow the output directory specified in the
  # kustomization to be in the git repo root's common output directory rather than spreading the
  # generated/templated manifests all over the directory. This makes for quick clean-up, reset, and
  # spot checking of the cluster state.
  kubectl kustomize --enable-helm --load-restrictor=LoadRestrictionsNone \
    -o "${manifest_output_file}" ./manifests/${manifest_id} >/dev/null

  if [ ! $? ]; then
    echo "failed to render ${manifest_id}" >&2
    return 3
  fi

  if ! manifest_sanity_check "${manifest_output_file}"; then
    echo "manifest failed sanity checks aborting generation" >&2
    return 4
  fi

  echo "successfully rendered ${manifest_id}" >&2
  return 0
}

# Perform various checks on generated manifests to ensure we don't run into known issues later on
# down the line...
manifest_sanity_check() {
  local rendered_file="${1:-}"
  local lint_status=0

  local file_base="${rendered_file%%.yaml}"

  if [ ! -f "${rendered_file}" ]; then
    echo "usage: manifest_sanity_check RENDERED_FILE" >&2
    return 1
  fi

  # We want ArgoCD to cleanly take over these resources once its up and running. Presence of the
  # helm managed label will require a manual and forceful adoption of the resources which we want to
  # avoid. This goes against best practices but we prefer this during bootstrapping as we explicitly
  # KNOW we don't want helm managing these.
  if grep -q "app.kubernetes.io/managed-by: Helm" "${rendered_file}"; then
    echo "found managed-by helm label in generated manifest" >&2
    lint_status=1
  fi

  # Extract any exceptions in the rendered manifest so we can properly omit the results from
  # policies that would otherwise fail our checks.
  yq -y 'select(.apiVersion == "kyverno.io/v2")' "${rendered_file}" > "${file_base}-kypols.yaml"

  # Note: Can set environment variables here such as deployment stage or environment which may be
  # useful or read in values using the -f flag. It does not respect any of the log CLI arguments
  # (at least around STDERR) so that is a dead end if a refactor comes around to this bit in the
  # future... The warning exit codes also don't seem to work with apply...
  local report="$(kyverno apply "${file_base}-kypols.yaml" ./policies/ --policy-report --resource  "${rendered_file}" |
    tail -n +6 |
    yq --compact-output --monochrome-output '.results[] | select(.result == "fail")'
  )"

  # We unfortunately can't rely on exit code here, it's not reporting them correctly so we'll just
  # see if there are any invalid results.
  if [ -n "${report}" ]; then
    echo -e "manifest failed to meet policy requirements, report results:\n" >&2

    # TODO: This report needs to be broken down line-by-line and turned into a more meaningful output
    echo "${report}" >&2

    # TODO: Don't fail the lint on these yet, they'll take a bit of work
    lint_status=0
  fi

  return ${lint_status}
}
