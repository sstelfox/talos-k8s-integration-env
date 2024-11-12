#!/usr/bin/env false

shared_patches=""
control_plane_patches=""
worker_patches=""


shared_patches="--config-patch @talos/firmament/cluster-meta.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/network/name_servers.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/network/time_servers.yaml ${shared_patches}"


shared_patches="--config-patch @talos/common/airgap_config/internal_discovery_service.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/airgap_config/ptp_host_clock.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/airgap_config/registry.yaml ${shared_patches}"


#control_plane_patches="--config-patch-control-plane @talos/common/debug/enable_workloads_on_control_plane.yaml ${control_plane_patches}"
#control_plane_patches="--config-patch-control-plane @talos/common/network/enable_vip.yaml ${control_plane_patches}"
control_plane_patches="--config-patch-control-plane @talos/common/security/restrict_system_services_control_network.yaml ${control_plane_patches}"


shared_patches="--config-patch @talos/common/network/internal_node_resolution.yaml ${shared_patches}"
#shared_patches="--config-patch @talos/common/security/kubelet_certificate_rotation.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/storage/enable_disk_encryption.yaml ${shared_patches}"
shared_patches="--config-patch @talos/common/health/enable_watchdog.yaml ${shared_patches}"


worker_patches="--config-patch-worker @talos/common/meta/annotate_worker_roles.yaml ${worker_patches}"


shared_patches="--config-patch @talos/common/network/disable_flannel.yaml ${shared_patches}"
control_plane_patches="--config-patch-control-plane @talos/common/network/setup_cillium.yaml ${control_plane_patches}"
