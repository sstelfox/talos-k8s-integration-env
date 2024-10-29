#!/usr/bin/env false

shared_patches=""
control_plane_patches=""
worker_patches=""

# Don't use network time, use the one provided by the VM host
shared_patches="--config-patch @machine_config_patches/airgapped_time_from_host.yaml ${shared_patches}"

# Once the kubelets are joined to the cluster, have them rotate their certificates so they can
# operate under the cluster's CA. This requires approval but this config fragment includes an
# automated approver.
#shared_patches="--config-patch machine_config_patches/kubelet_certificate_rotation.yaml ${shared_patches}"

# Allow the local DNS server to resolve nodes
shared_patches="--config-patch @machine_config_patches/internal_node_resolution.yaml ${shared_patches}"

# Switch internally for this to remove another external dependency for the cluster.
shared_patches="--config-patch @machine_config_patches/internal_discovery_service.yaml ${shared_patches}"

# Basic disk encryption
shared_patches="--config-patch @machine_config_patches/enable_disk_encryption.yaml ${shared_patches}"

# Redirect all of the registries the system needs to the airgapped self-hosted one
shared_patches="--config-patch @machine_config_patches/airgapped_registry.yaml ${shared_patches}"

# Alright this is the big one, install Cillium as the underlying CNI...
#shared_patches="--config-patch @machine_config_patches/disable_flannel.yaml ${shared_patches}"
#control_plane_patches="--config-patch-control-plane @machine_config_patches/install_cillium.yaml ${control_plane_patches}"

# Needs to be customized to the layer 2 network and possibly specific machines, mostly left here as
# an example.
#control_plane_patches="--config-patch-control-plane @machine_config_patches/enable_vip_control_plane.yaml ${control_plane_patches}"

# Limit our control traffic to our private network
control_plane_patches="--config-patch-control-plane @machine_config_patches/restrict_system_services_control_network.yaml ${control_plane_patches}"

# Custom Pause Image: Systemwide CRI pinned image overrides
#shared_patches="--config-patch @machine_config_patches/custom_pause_image.yaml ${shared_patches}"

# For my underlying host this is a largely static config with almost no workloads, its purely for
# managing KubeVirt machines and the resources are entirely given over to those. In this environment
# I want the workloads running on the control plane.
#control_plane_patches="--config-patch-control-plane @machine_config_patches/enable_workloads_on_control_plane.yaml ${control_plane_patches}"

# Fire off a copy of all the logs generated using UDP at this host, should not be used in
# production.
#shared_patches="--config-patch @machine_config_patches/blind_logs.yaml ${shared_patches}"
