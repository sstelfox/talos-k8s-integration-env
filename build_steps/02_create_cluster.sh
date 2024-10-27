#!/usr/bin/env sh

set -o errexit

mkdir -p ~/.talos/clusters _out/

if [ ! -f _out/secrets.yaml ]; then
  talosctl gen secrets -o _out/secrets.yaml
fi

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

# For my underlying host this is a largely static config with almost no workloads, its purely for
# managing KubeVirt machines and the resources are entirely given over to those. In this environment
# I want the workloads running on the control plane.
#cat machine_config_patches/enable_workloads_on_control_plane.yaml \
#  >>_out/birthright_patches_control_plane_only.yaml

# Generate our actual config, this should be reviewed before creation
talosctl gen config --with-secrets _out/secrets.yaml \
  ${shared_patches} ${control_plane_patches} ${worker_patches} \
  --talosconfig ./_out/talosconfig --output ./_out/ --force \
  firmament-integration https://10.5.0.1:6443

# We can't create a qemu cluster from already generated configs so we'll just apply the same
# patches for now. I may want to instead see if I can create than pull the configs
#sudo --preserve-env=HOME talosctl cluster create --provisioner qemu \
#  --talosconfig $(pwd)/_out/talosconfig --with-secrets $(pwd)/_out/secrets.yaml \
#  --config-patch @_out/birthright_patches.yaml \
#  --config-patch-control-plane @_out/birthright_patches_control_plane_only.yaml \
#  --config-patch-worker @_out/birthright_patches_worker_only.yaml \
#  --controlplanes 3 --workers 2 \
#  --cpus 2.0 --cpus-workers 4.0 --memory 2048 --memory-workers 4096 \
#  --disk 6144 --extra-disks 1 --extra-disks-size 5120 \
#  --name firmament-integration \
#  --dns-domain firmament-integration.k8s.grayiron.io
# --disk-encryption-key-types kms --encrypt-ephemeral --encrypt-state --with-tpm2 --with-uefi \
# --extra-uefi-search-paths /usr/share/ovmf/x64/ \
# --registry-mirror ghcr.io=http://10.5.0.1:6000

#sudo chown -R sstelfox:sstelfox ${HOME}/.talos
