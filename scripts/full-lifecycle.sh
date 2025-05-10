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

case "${TALOS_SOURCE}" in
"github-official")
  ./scripts/source_installer/00_official_github_release.sh
  ;;
*)
  echo "unknown source location for talos base installer and images" >&2
  ;;
esac

# todo(sstelfox): this does more than just start the containers providing specific services, it
#   also populates the image store and generates the initial manifests that need to be present via
#   the web server during cluster bring up. I need to split this script up into those respective
#   functions.
./scripts/start-installer-services.sh

# This creates our initial cluster according to the config and its own policies. This could use more
# parameterization but is good enough for the purpose of integration testing all the components and
# configurations for now.
#
# This relies on initial manifests and will bring up the cluster into a fairly minimal state. This
# consists of a relatively insecure network and only minimal configuration.
./scripts/create_firmament.sh

# Start bringing up the initial parts of the environment. This is primarily the infrastructure such
# as storage, secret handling, networking, firewall, and policy enforcement. This sets up ArgoCD
# and the code forge which will take over the deployment and management of the clsuter in the next
# stage.
./scripts/stages/bootstrap/execute-stage.sh
