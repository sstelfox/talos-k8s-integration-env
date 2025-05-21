# Talos Kubernetes Integration Environment

I needed the ability to quickly setup and tear down something that looked a bit more like a
production cluster than what other "dev" clusters could provide. This repo is still largely a work
in progress and I'll likely frequently be breaking it in weird ways but some of the patterns,
configurations, workflows, and considerations may be useful to others.

The services currently present in the repo, but may not be fully configured are:

* ArgoCD
* Cert-Manager
* Cilium
* Kyverno
* Rook/Ceph
* Vault

Outstanding services that I intend to stand-up but haven't yet:

* Dependency Track
* Falco
* Forgejo
* Keycloak?
* Loki
* Grafana
* Plane (<https://github.com/makeplane/plane>)
* Postgres (likely using an operator)
* Promtail
* SIEM? Wazah?
* Tempo
* Valkey/Redis/Redis-Clusters (likely using an operator)

## Development Dependencies

The following binaries are expected to be in your working path to run the various script. May
create a nix flake for this development environment eventually.

* helm
* jq
* yq
* kubectl
* kyverno
* skopeo
* cilium-cli

## Cluster Bring Up

The cluster comes up in three stages:

* The initial manifests applied while Talos is installing. I refer to this as the init phase. We
  need to install Cilium during this time for the cluster's networking to become healthy allowing
  us to continue the bring-up.
* The bootstrap phase extends the configuration into a more complete but still minimal setup,
  fine-tuning of the network, basic storage availability, security policy enforcement, etc. The
  final stage of this sets up ArgoCD to transition us to the last stage.
* The stable stage loads the full structure up using an app of apps style manifest in Argo which
  will also take over the services setup in the previous stages. Part of this transition is switching
  the source to an in-cluster code forge to be the source of truth for ArgoCD.

## Usage

The scripts in this repository are assuming you have podman working on your system and can perform a
talosctl provision using qemu. To create a cluster you'll need to download the relevant sources
(script is provided), start a local registry and some initialization manifests, then trigger the
creation. This can be done with the following scripts:

```console
./scripts/source_installer/00_official_github_release.sh
./scripts/start-installer-services.sh
./scripts/create_firmament.sh
```

The scripts should be fairly accessible and I've commented them enough they shouldn't be hard to
follow. Give the repo a star if you find it useful.
