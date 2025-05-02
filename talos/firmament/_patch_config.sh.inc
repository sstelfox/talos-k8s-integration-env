#!/usr/bin/env false

shared_patches=""
control_plane_patches=""
worker_patches=""


add_control() {
  local patch_path="${1:-}"
  control_plane_patches="--config-patch-control-plane @talos/${patch_path} ${control_plane_patches}"
}

add_shared() {
  local patch_path="${1:-}"
  shared_patches="--config-patch @talos/${patch_path} ${shared_patches}"
}

add_worker() {
  local patch_path="${1:-}"
  worker_patches="--config-patch-worker @talos/${patch_path} ${worker_patches}"
}


# Cluster specific configuration
add_shared firmament/cluster-meta.yaml


# Core network and system service configs
add_shared common/health/enable_watchdog.yaml
add_shared common/network/internal_node_resolution.yaml
add_shared common/network/name_servers.yaml
add_shared common/network/time_servers.yaml
add_control common/security/restrict_system_services_control_network.yaml


# Host configuration
# TODO: this still needs a lot of work but at lest it is encrypted even if its barely protected
add_shared common/storage/enable_disk_encryption.yaml


# Airgapped customizations
add_shared common/airgap_config/internal_discovery_service.yaml
add_shared common/airgap_config/ptp_host_clock.yaml
add_shared common/airgap_config/registry.yaml


#add_shared common/network/disable_flannel.yaml
#add_control common/network/setup_cillium.yaml


# Don't remember what this was for...
#add_worker common/meta/annotate_worker_roles.yaml
# ... but maybe this was related?
#add_control common/debug/enable_workloads_on_control_plane.yaml


# Unstable policies
#add_control common/network/enable_vip.yaml
#add_control common/security/control_plane_firewall.yaml
#add_shared common/security/kubelet_certificate_rotation.yaml
#add_worker common/security/worker_firewall.yaml
