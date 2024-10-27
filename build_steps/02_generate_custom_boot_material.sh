#!/usr/bin/env sh

set -o errexit

mkdir -p _out/

talosctl gen secureboot uki --common-name "Firmament SecureBoot Key"
talosctl gen secureboot pcr
