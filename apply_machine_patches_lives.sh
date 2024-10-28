#!/usr/bin/env sh

set -o errexit

if [ ! -f "$1" ]; then
  echo "must provide file to apply"
  exit 1
fi

for machine_ip in 6 5 4 3 2; do
  talosctl machineconfig patch $1 -e 10.5.0.2 -n 10.5.0.${machine_ip} >/dev/null
done
