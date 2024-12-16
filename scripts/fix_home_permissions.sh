#!/usr/bin/env sh

set -o errexit

sudo chown -R sstelfox:sstelfox ${HOME}/.talos ${HOME}/.kube &>/dev/null
