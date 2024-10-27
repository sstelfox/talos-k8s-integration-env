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
#cat machine_config_patches/enable_vip_control_plane.yaml >>_out/birthright_patches_control_plane_only.yaml

# Limit our control traffic to our private network
control_plane_patches="--config-patch-control-plane @machine_config_patches/restrict_system_services_control_network.yaml ${control_plane_patches}"
