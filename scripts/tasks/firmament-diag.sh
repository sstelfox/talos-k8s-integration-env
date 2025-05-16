#!/usr/bin/env sh

NODE_IP="${1:-10.5.0.2}"

./_out/talosctl cluster show --provisioner qemu --name firmament-integration

timeout 15s ./_out/talosctl health -n "${NODE_IP}"
timeout 15s ./_out/talosctl -n "${NODE_IP}" get securitystate

# To look at logs for specific services
#./_out/talosctl --cluster firmament-integration -n 10.5.0.2 logs apid
#./_out/talosctl --cluster firmament-integration -n 10.5.0.2 logs containerd
#./_out/talosctl --cluster firmament-integration -n 10.5.0.2 logs cri
#./_out/talosctl --cluster firmament-integration -n 10.5.0.2 logs kubelet

# When the early CNI hasn't come up
#./_out/talosctl --cluster firmament-integration -n 10.5.0.2 kubeconfig
#kubectl logs -n kube-system job/cilium-install

#kubectl get nodes -o wide
#kubectl get pods -o wide -A

#./_out/talosctl get machineconfig -n 10.5.0.2 -o yaml > controlplane.yaml
#./_out/talosctl get machineconfig -n 10.5.0.5 -o yaml > worker.yaml
