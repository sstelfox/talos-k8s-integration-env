#!/usr/bin/env sh

set -o errexit

source machine_config_patches/_enabled_patches.sh.inc

mkdir -p _out/

if [ ! -f _out/secrets.yaml ]; then
  talosctl gen secrets -o _out/secrets.yaml
fi

# Generate our actual config, this should be reviewed before creation
talosctl gen config --with-secrets _out/secrets.yaml \
  ${shared_patches} ${control_plane_patches} ${worker_patches} \
  --talosconfig ./_out/talosconfig --output ./_out/ --force \
  firmament-integration https://10.5.0.1:6443
