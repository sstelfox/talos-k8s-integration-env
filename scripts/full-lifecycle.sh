#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

if [ "${EUID}" = "0" ]; then
  echo "this does make use of privileged operations but you don't need to sudo it directly" >&2
  echo "so cowardly aborting. run this as a normal user with sudo permissions and we'll ask" >&2
  echo "when we need the permissions" >&2

  exit 1
fi

source ./scripts/cfg/talos.sh.inc
source ./scripts/lib/manifests.sh.inc

case "${TALOS_SOURCE}" in
"github-official")
  ./scripts/source_installer/00_official_github_release.sh
  ;;
  # todo(sstelfox): Build / customize our own image? We could use it to bootstrap the installer
*)
  echo "unknown source location for talos base installer and images" >&2
  ;;
esac

# Start a webserver for basic file serving and an image repository
./scripts/run-support-service-containers.sh

# Before creating the cluster, we need to ensure that our bring-up networking config is fully up to
# date.
manifest_render cilium/bring-up
cp -f ./_out/manifests/cilium-bring-up.yaml ./_out/public/cilium-bring-up.yaml

# This creates our initial cluster according to the config and its own policies. This could use more
# parameterization but is good enough for the purpose of integration testing all the components and
# configurations for now.
#
# This relies on initial manifests and will bring up the cluster into a fairly minimal state. This
# consists of a relatively insecure network and only minimal configuration.
./scripts/create_firmament.sh

# Start bringing up the initial parts of the environment. This is primarily the infrastructure such
# as storag and secret handling.
./scripts/stages/init/execute-stage.sh

# At this point we have working encrypted storage, secure auditable secret storage, and are setup to
# enforce strong network policies. We want to start applying our security enforcement mechanisms in
# this stage, setup our user authentication, the code forge, and finally argocd to take over the
# management of the cluster.
./scripts/stages/bootstrap/execute-stage.sh
