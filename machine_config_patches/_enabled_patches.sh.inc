#!/usr/bin/env false

shared_patches=""
control_plane_patches=""
worker_patches=""

# Don't use network time, use the one provided by the VM host
shared_patches="--config-patch @machine_config_patches/airgapped_time_from_host.yaml ${shared_patches}"

# Redirect all of the registries the system needs to the airgapped self-hosted one
shared_patches="--config-patch @machine_config_patches/airgapped_registry.yaml ${shared_patches}"

# Needs to be customized to the layer 2 network and possibly specific machines, mostly left here as
# an example.
#control_plane_patches="--config-patch-control-plane @machine_config_patches/enable_vip_control_plane.yaml ${control_plane_patches}"

# Limit our control traffic to our private network
control_plane_patches="--config-patch-control-plane @machine_config_patches/restrict_system_services_control_network.yaml ${control_plane_patches}"

# For my underlying host this is a largely static config with almost no workloads, its purely for
# managing KubeVirt machines and the resources are entirely given over to those. In this environment
# I want the workloads running on the control plane.
#control_plane_patches="--config-patch-control-plane @machine_config_patches/enable_workloads_on_control_plane.yaml ${control_plane_patches}"
