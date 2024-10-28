#!/usr/bin/env sh

sudo --preserve-env=HOME talosctl cluster show --provisioner qemu --name firmament-integration
kubectl get nodes -o wide
talosctl health --nodes 10.5.0.2

#talosctl read -n 10.5.0.2 /system/state/config.yaml > controlplane.yaml
#talosctl read -n 10.5.0.5 /system/state/config.yaml > worker.yaml
