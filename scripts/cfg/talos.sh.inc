#/usr/bin/env false

# Common definitions we'll re-use throughout the cluster creation process to ensure everything is
# consistent and can be updated / tweaked in a single location.

TALOS_ARCH="amd64"
TALOS_VERSION="v1.10.0"
CILIUM_VERSION="v1.17.2"
# I'm not sure why this differs... Or how to keep track of it. I just installed using the latest
# cilium-ci-cli version and grabbed the image versions from cilium status.
CILIUM_ENVOY_VERSION="v1.31.5"

TALOS_SOURCE="github-official"

TALOS_CLUSTER_NAME="firmament-integration"
