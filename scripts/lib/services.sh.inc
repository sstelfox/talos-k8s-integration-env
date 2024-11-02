#!/usr/bin/env false

service_check_available() {
  local container_name="${1:-}"

  if [ -z "${container_name}" ]; then
    echo "usage: service_exists CONTAINER_NAME" >&2
    exit 1
  fi

  if service_exists "${container_name}"; then
    if ! service_is_running "${container_name}"; then
      podman start "${container_name}" >/dev/null 2>&1
      echo "existing service started back up" >&2
    fi

    return 0
  fi

  return 1
}

service_exists() {
  local container_name="${1:-}"

  if [ -z "${container_name}" ]; then
    echo "usage: service_exists CONTAINER_NAME" >&2
    exit 1
  fi

  podman container exists "${container_name}" >/dev/null 2>&1
}

service_is_running() {
  local container_name="${1:-}"

  if [ -z "${container_name}" ]; then
    echo "usage: service_exists CONTAINER_NAME" >&2
    exit 1
  fi

  podman container inspect "${container_name}" \
    --format "{{.State.Running}}" 2>/dev/null | grep -q "true"
}
