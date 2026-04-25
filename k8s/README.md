# Cluster workloads (GitOps via ArgoCD)

```
k8s/
  bootstrap/             # one-shot: install ArgoCD + apply root Application
    install-argocd.sh
    root-app.yaml
  apps/                  # ArgoCD app-of-apps watches this directory
    monitoring.yaml      # one Application per workload
  charts/                # local values files for upstream charts
    monitoring/
      values.yaml
```

## Bootstrap (once per cluster)

```bash
bash k8s/bootstrap/install-argocd.sh
```

This installs ArgoCD into the `argocd` namespace and applies the root
Application. The root app then discovers every manifest under `k8s/apps/`
and brings them online.

## Day-to-day

To add a new workload: drop an `Application` manifest into `k8s/apps/`,
commit, push. ArgoCD picks it up on its next refresh (auto-syncs by default).

To change values for an existing workload: edit the matching file in
`k8s/charts/<name>/values.yaml`, commit, push. ArgoCD reconciles.

## Adopting the existing monitoring release

The cluster already has a `monitoring` Helm release of `kube-prometheus-stack`
83.4.3. The Application in `k8s/apps/monitoring.yaml` matches that release
name and chart version, so first sync should adopt the existing resources
in place rather than redeploy them.

Before first sync, create the Grafana admin secret so the chart doesn't
generate a fresh password:

```bash
kubectl -n monitoring create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='<choose-one>'
```

After the secret exists, run the bootstrap script (or kubectl-apply
`root-app.yaml`). Watch sync status with:

```bash
kubectl -n argocd get applications
```
