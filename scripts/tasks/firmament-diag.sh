#!/usr/bin/env sh

NODE_IP="${1:-10.5.0.2}"

./_out/talosctl cluster show --provisioner qemu --name firmament-integration

timeout 15s ./_out/talosctl health -n "${NODE_IP}"
timeout 15s ./_out/talosctl -n "${NODE_IP}" get securitystate

kubectl get nodes -o wide
kubectl get pods -o wide

#./_out/talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.2 > controlplane.yaml
#./_out/talosctl read /system/state/config.yaml --cluster firmament-integration -n 10.5.0.5 > worker.yaml
