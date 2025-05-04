#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

source ./scripts/cfg/talos.sh.inc

case "${TALOS_SOURCE}" in
"github-official")
  ./scripts/source_installer/00_official_github_release.sh
  ;;
*)
  echo "unknown source location for talos base installer and images" >&2
  ;;
esac

./scripts/start-installer-services.sh
./scripts/create_firmament.sh

# The installer services ensures the bootstrap manifests are up to date when it gets run, we don't
# need the additional manifests until we start setting up the initial environment.
./scripts/generate-manifests.sh

./scripts/bootstrap-apps.sh
