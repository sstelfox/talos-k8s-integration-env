#!/usr/bin/env sh

set -o errexit

source machine_config_patches/_enabled_patches.sh.inc

mkdir -p _out/

if [ ! -f _out/secrets.yaml ]; then
  talosctl gen secrets -o _out/secrets.yaml
fi

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
