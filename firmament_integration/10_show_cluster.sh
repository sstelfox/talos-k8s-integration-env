#!/usr/bin/env sh

sudo --preserve-env=HOME talosctl cluster show --provisioner qemu --name firmament-integration
kubectl get nodes -o wide
talosctl health --nodes 10.5.0.2

#talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.2 > controlplane.yaml
#talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.5 > worker.yaml
