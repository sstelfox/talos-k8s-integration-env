#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

export SOPS_AGE_KEY_FILE="./secrets/identities/sstelfox.pub"

sops $@
