#!/usr/bin/env bash

sudo --preserve-env=HOME ./_out/talosctl cluster destroy --provisioner qemu --name firmament-integration
