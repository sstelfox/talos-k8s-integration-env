#!/usr/bin/env bash

sudo --preserve-env=HOME talosctl cluster destroy --provisioner qemu --name talos-default
rm -rf ~/.talos/{clusters,config}
