#!/usr/bin/env false

check_tcp_port_listening() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    if ss -tln "sport = :${port}" 2>/dev/null | grep -q LISTEN; then
      return 0
    fi

    return 1
  fi

  if command -v netstat >/dev/null 2>&1; then
    if netstat -tnla 2>/dev/null | grep -q "^tcp.*\.${port}[[:space:]]*[*.][*.][[:space:]]*LISTEN\|^tcp.*:${port}[[:space:]]*.*LISTEN"; then
      return 0
    fi

    return 1
  fi

  echo "Error: Neither 'ss' nor 'netstat' found. One is required for TCP port checking." >&2
  return 2
}

cmd_with_k8s_port_forward() {
  namespace="$1"
  service="$2"
  ports="$3"

  shift 3

  if [ -z "${namespace}" ] || [ -z "${service}" ] || [ -z "${ports}" ] || [ $# -eq 0 ]; then
    echo "usage: cmd_with_k8s_port_forward NAMESPACE SERVICE LOCAL:REMOTE_PORT COMMAND [ARGS...]" >&2
    return 1
  fi

  if ! kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    echo "error: namespace '${namespace}' does not exist\n" >&2
    return 2
  fi

  if ! kubectl -n "${namespace}" get service "${service}" >/dev/null 2>&1; then
    echo "error: service '${service}' not found in namespace '${namespace}'" >&2
    return 3
  fi

  local_port="${ports%%:*}"

  kubectl port-forward -n "${namespace}" "service/${service}" "${ports}" >/dev/null 2>&1 &
  port_forward_pid=$!

  if ! kill -0 "${port_forward_pid}" >/dev/null 2>&1; then
    echo "Error: Port-forward failed to start" >&2
    return 4
  fi

  if ! wait_tcp_port_listening "${local_port}"; then
    echo "error: TCP port ${local_port} did not start listening within timeout" >&2

    kill "${port_forward_pid}" >/dev/null 2>&1 || true
    wait "${port_forward_pid}" 2>/dev/null || true

    return 5
  fi

  eval "$@"
  return_code=$?

  kill "${port_forward_pid}" >/dev/null 2>&1 || true
  wait "${port_forward_pid}" 2>/dev/null || true

  return "${return_code}"
}

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

wait_tcp_port_listening() {
  local port="${1:-}"

  if [ -z "${port}" ]; then
    echo "usage: wait_tcp_port_listening PORT" >&2
    return 1
  fi

  local max_attempts=30
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if check_tcp_port_listening "${port}"; then
      return 0
    fi

    if sleep 0.1 2>/dev/null; then
      attempt=$((attempt + 1))
    elif sleep 1 2>/dev/null; then
      attempt=$((attempt + 10))
    else
      echo "error: failed to sleep while waiting for port to become available" >&2
      return 2
    fi
  done

  return 3
}
