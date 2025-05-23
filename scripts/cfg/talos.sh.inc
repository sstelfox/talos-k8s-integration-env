#/usr/bin/env false

# Common definitions we'll re-use throughout the cluster creation process to ensure everything is
# consistent and can be updated / tweaked in a single location.

TALOS_ARCH="amd64"
TALOS_VERSION="v1.10.0"
CILIUM_VERSION="v1.17.3"

TALOS_SOURCE="github-official"

TALOS_CLUSTER_NAME="firmament-integration"
CLUSTER_DOMAIN="firmament-integration.k8s.grayiron.io"

REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"
SECRETS_DIR="${REPO_ROOT_DIR}/_out/secrets"
