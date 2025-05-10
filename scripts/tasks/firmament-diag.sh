#!/usr/bin/env sh

./_out/talosctl cluster show --provisioner qemu --name firmament-integration
./_out/talosctl health -n 10.5.0.2
./_out/talosctl -n 10.5.0.2 get securitystate

kubectl get nodes -o wide

#./_out/talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.2 > controlplane.yaml
#./_out/talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.5 > worker.yaml
