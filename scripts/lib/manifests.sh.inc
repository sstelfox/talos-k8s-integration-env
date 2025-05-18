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

  local manifest_root="${manifest_id%/*}"

  if [ -x "./manifests/${manifest_root}/base/sync.sh" ]; then
    echo "detected sync script for manifest, triggering before render" >&2

    if ! "./manifests/${manifest_root}/base/sync.sh"; then
      echo "sync script failed. manifest may be unavailable or invalid, aborting" >&2
      return 3
    fi
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
    return 4
  fi

  if ! manifest_sanity_check "${manifest_id}"; then
    echo "manifest failed sanity checks aborting generation" >&2
    return 5
  fi

  echo "successfully rendered ${manifest_id}" >&2
}

format_kyverno_report() {
  if [ -t 0 ]; then
    echo "must pipe in the report via stdin" >&2
    exit 1
  fi

  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # We process the kyverno report one line at a time, formatting it into something more readable
    echo "$line" | jq -r '
      # Format the header: [SEVERITY][policy/rule]: message (without trailing period)
      "  [" + (.severity | ascii_upcase) + "]" +
      "[" + .policy + "/" + .rule + "]: " +
      (.message | rtrimstr(".")) + "\n" +

      # Format each resource with namespace/name
      (.resources | map("    - " + .kind + ": " + .namespace + "/" + .name) | join("\n"))
    '
  done < /dev/stdin
}

# Perform various checks on generated manifests to ensure we don't run into known issues later on
# down the line...
manifest_sanity_check() {
  local manifest_id="${1:-}"

  if [ -z "${manifest_id}" ]; then
    echo "usage: render_manifest MANIFEST_ID" >&2
    return 1
  fi

  local rendered_file="$(manifest_output_file "${manifest_id}")"
  local lint_status=0

  # We want ArgoCD to cleanly take over these resources once its up and running. Presence of the
  # helm managed label will require a manual and forceful adoption of the resources which we want to
  # avoid. This goes against best practices but we prefer this during bootstrapping as we explicitly
  # KNOW we don't want helm managing these.
  if grep -q "app.kubernetes.io/managed-by: Helm" "${rendered_file}"; then
    echo "found managed-by helm label in generated manifest" >&2
    lint_status=1
  fi

  # Some helm charts are setup poorly and accidentally include test resources. We want to make sure
  # we've filtered those out of the relevant helm charts to keep the security boundary nice and
  # tight.
  if grep -q "helm.sh/hook: test" "${rendered_file}"; then
    echo "found leaked test resources in generated manifest" >&2
    lint_status=1
  fi

  # We'll use this base-name to create some additional files in the output directory
  local file_base="${rendered_file%%.yaml}"

  # Extract any exceptions in the rendered manifest so we can properly omit the results from
  # policies that would otherwise fail our checks.
  yq -y 'select(.kind == "PolicyException" or .kind == "ClusterPolicyException")' "${rendered_file}" > "${file_base}-policy-exceptions.yaml"

  # During the init phase the Kyverno CRDs aren't installed so we can't include the exceptions
  # directly and still apply them to the cluster. To work around this only for the init phase we'll
  # look for and append additional init-specific exceptions.
  case "$manifest_id" in
    */init)
      if [ -f "./manifests/${manifest_id}/kyverno-policy-exceptions.yaml" ]; then
        echo "including init specific policy exceptions" >&2
        cat "./manifests/${manifest_id}/kyverno-policy-exceptions.yaml" >> "${file_base}-policy-exceptions.yaml"
      fi
      ;;
  esac

  # Note: Can set environment variables here such as deployment stage or environment which may be
  # useful or read in values using the -f flag. It does not respect any of the log CLI arguments
  # (at least around STDERR) so that is a dead end if a refactor comes around to this bit in the
  # future... The warning exit codes also don't seem to work with apply...
  kyverno apply --exceptions "${file_base}-policy-exceptions.yaml" --policy-report \
    --audit-warn --remove-color --resource  "${rendered_file}" ./policies/ |
    tail -n+2 > _out/tmp-policy-report.out

  local report
  report="$(yq --compact-output --monochrome-output  '.results[] | select(.result == "fail")' _out/tmp-policy-report.out)"

  # We unfortunately can't rely on exit code here, it's not reporting them correctly so we'll just
  # see if there are any invalid results.
  if [ -n "${report}" ]; then
    echo "manifest failed to meet policy requirements:" >&2
    echo "${report}" | format_kyverno_report >&2

    # Generate a file that can be used to create exceptions from the detection
    kyverno apply --exceptions "${file_base}-policy-exceptions.yaml" --remove-color \
      --resource "${rendered_file}" --generate-exceptions ./policies/ > "${file_base}-missing-exceptions.yaml"

    # TODO: Don't fail the lint on these yet, they'll take a bit of work
    #lint_status=1
  fi

  return ${lint_status}
}
