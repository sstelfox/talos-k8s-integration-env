#!/usr/bin/env sh

set -o errexit

for machine_ip in 2 3 4 5 6; do
  sudo --preserve-env=HOME talosctl -e 10.5.0.2 -n 10.5.0.${machine_ip} \
    machineconfig patch -p @machine_patches/initialize_audit_policy.yaml
done
