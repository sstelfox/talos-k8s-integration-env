#!/usr/bin/env sh

talosctl cluster show --provisioner qemu --name firmament-integration
talosctl health -n 10.5.0.2
talosctl -n 10.5.0.2 get securitystate

kubectl get nodes -o wide

#talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.2 > controlplane.yaml
#talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.5 > worker.yaml
