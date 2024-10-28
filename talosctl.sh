#!/usr/bin/env sh

#talosctl --talosconfig ./_out/talosconfig $@

sudo --preserve-env=HOME talosctl cluster $@
