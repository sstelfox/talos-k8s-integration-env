#!/usr/bin/env sh

sudo --preserve-env=HOME talosctl cluster show --provisioner qemu --name firmament-integration
kubectl get nodes -o wide
