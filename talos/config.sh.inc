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
if [ -f "./talos/clusters/${TALOS_CLUSTER_NAME}.yaml" ]; then
  add_shared "clusters/${TALOS_CLUSTER_NAME}.yaml"
else
  echo "cluster specific configuration for '${TALOS_CLUSTER_NAME}' was not found" >&2
  exit 3
fi


# Core network and system service configs
add_shared common/health/enable_watchdog.yaml
add_shared common/network/internal_node_resolution.yaml
add_shared common/network/name_servers.yaml
add_shared time_synchronization.yaml
add_control common/security/restrict_system_services_control_network.yaml


# Host configuration
# TODO: this still needs a lot of work but at lest it is encrypted even if its barely protected
add_shared common/storage/enable_disk_encryption.yaml

# By default Talos gives control plane nodes a role, but leaves the other nodes without anything.
# For consistency we'll give an annotation to the worker nodes as well so we can target these nodes
# specifically with placement rules.
#
# This could be used to create multiple node groups and target them indepdently as well.
#
# Note: this is currently disabled as the workers fail to come up after applying this. It's possible
# Talos itself is rejecting the update or I did something incorrect here.
#add_worker common/meta/annotate_worker_roles.yaml

# Needed to allow the local-path-provisioner the ability to write to the ephemeral partition
add_shared storage_local_write_mount.yaml


# Airgapped customizations
add_shared common/airgap_config/internal_discovery_service.yaml
add_shared common/airgap_config/registry.yaml


add_shared cilium/disable_flannel.yaml
#add_control cilium/install_cilium_ci_utility.yaml
add_control cilium/install_cilium_manifest.yaml

# ... but maybe this was related?
#add_control common/debug/enable_workloads_on_control_plane.yaml


# Unstable policies
#add_control common/network/enable_vip.yaml
#add_control common/security/control_plane_firewall.yaml
#add_shared common/security/kubelet_certificate_rotation.yaml
#add_worker common/security/worker_firewall.yaml
