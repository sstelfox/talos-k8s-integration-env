# Known Outstanding Tasks

## Bootstrap

### Cluster Bring Up

* [ ] Cilium
* [ ] Hardened network policies
* [ ] Kyverno
* [ ] Keyverno policies
* [ ] Policy enablement
* [ ] Ceph/Rook
* [ ] Initial providers

### Transition to GitOps

* [ ] Cilium needs to take ownership w/o error over the resources deployed during bring up
* [ ] Vault?
* [ ] ArgoCD

### GitOps Takeover

* [ ] Ensure all infrastructure services are configured for HA
* [ ] Loki/Mimir/Grafrana/Tempo
* [ ] Falco
* [ ] KeyCloak? Some other options available here
* [ ] Metric server / VPA / HPA

## Final Certification

* [ ] Ensure the argocd/argocd-initial-admin-secret has been removed
* [ ] Ensure PVCs are individually encrypted (ceph, vault)
* [ ] Perform full bootstrap in air-gapped environment
* [ ] Validate no external connections are made passively for a 48 hour window
* [ ] Perform review of all roles and bindings
* [ ] Ensure administrative access is only available by assuming a higher role (behalf of)
* [ ] Ensure internal k8s certificates are configured for automatic rotation
