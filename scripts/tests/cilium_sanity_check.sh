#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

cilium connectivity test
cilium connectivity perf
