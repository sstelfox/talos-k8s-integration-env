#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# Primary functional test to ensure everything
cilium connectivity test

# This one currently isn't working and takes a long time to timeout. The current PSS policies are
# restricting it from using RAW sockets it needs to measure connection setup/hold/teardown. This
# would be a nice test to run and sanity check but its a minor item and going to live here as tech
# debt.
#cilium connectivity perf
