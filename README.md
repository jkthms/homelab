# homelab

Infrastructure-as-code for the **apex** cluster — three Ubuntu 24.04 nodes
running [K3s](https://k3s.io) in HA mode with embedded etcd. Workloads on
the cluster are managed declaratively from this repo via
[ArgoCD](https://argo-cd.readthedocs.io).

---

## Topology

```
                          Internet
                              │
                              ▼
                    ┌──────────────────┐
                    │  UniFi Gateway   │
                    │   192.168.1.1    │
                    └─────────┬────────┘
                              │
                       ┌──────┴──────┐
                       │  L2 Switch  │
                       └──────┬──────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
        ┌─────┴──────┐  ┌─────┴──────┐  ┌─────┴──────┐
        │ apex.dev01 │  │ apex.dev02 │  │ apex.dev03 │
        │ .50        │  │ .51        │  │ .52        │
        ├────────────┤  ├────────────┤  ├────────────┤
        │ Ubuntu     │  │ Ubuntu     │  │ Ubuntu     │
        │ 24.04 LTS  │  │ 24.04 LTS  │  │ 24.04 LTS  │
        │ K3s server │  │ K3s server │  │ K3s server │
        │ + etcd     │  │ + etcd     │  │ + etcd     │
        └────────────┘  └────────────┘  └────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                  ┌───────────┴───────────┐
                  │  Traefik LoadBalancer │
                  │  80/TCP, 443/TCP      │
                  │  on .50, .51, .52     │
                  └───────────────────────┘
```

All three nodes are K3s **servers** (control plane + etcd). Three is an odd
number, so etcd can hold a majority quorum even if any one node fails —
that's what makes the cluster highly available. Additional capacity is
added as **agent** (worker) nodes, which run workloads but don't
participate in the control plane.

---

## How it works

A short tour of the moving parts. The repo's own internal docs go deeper.

**Kubernetes** treats the three nodes as one big machine. You describe the
state you want as YAML — *"two copies of Grafana, exposed on port 3000"* —
and Kubernetes places the workloads onto nodes, restarts them on failure,
and reschedules them if a node disappears. The atomic unit is a **pod** (a
container or two that always run together); higher-level objects like
**Deployments** and **Services** manage pods on your behalf.

**K3s** is a lightweight Kubernetes distribution from Rancher. Same APIs and
same YAML as upstream Kubernetes, but one binary and a fraction of the
RAM — the right fit for a homelab.

**etcd** is the small key-value database that stores cluster state. It
needs an odd number of replicas so writes can require a *majority vote*.
With 3 servers the cluster tolerates 1 failure; with 5 it tolerates 2.
Even numbers are wasteful — 4 servers tolerate the same failures as 3,
just with more etcd write traffic.

**Helm** is the package manager for Kubernetes. A *chart* is a templated
bundle of YAML with a `values.yaml` of knobs you override. We use it for
upstream things like `kube-prometheus-stack` (Prometheus + Grafana +
Alertmanager + glue).

**ArgoCD + GitOps.** Rather than `helm install`-ing things by hand, the
desired state of the cluster lives in this repo. ArgoCD runs *inside* the
cluster, watches `k8s/apps/`, and reconciles reality to match. To deploy
something new: write an `Application` manifest, commit, push. ArgoCD picks
it up. To remove something: delete the file. The "app of apps" pattern
(one root `Application` that watches a directory of more `Application`s)
means you only ever have to bootstrap one thing manually — ArgoCD
discovers the rest.

So the end-to-end story for adding, say, Redis: drop
`k8s/charts/redis/values.yaml` and `k8s/apps/redis.yaml` into the repo,
commit, push. ArgoCD renders the Bitnami chart with your values, diffs
against the cluster, applies the missing resources. The Kubernetes
scheduler picks a node, `kubelet` starts the container, etcd records the
state. If that node later dies, the scheduler moves Redis to a surviving
node and the `Service` IP redirects transparently.

---

## Repo layout

```
ansible/    # bootstraps fresh Ubuntu hosts → working K3s server
k8s/        # ArgoCD-managed cluster workloads (app-of-apps pattern)
Makefile    # shortcuts: make help
```

Operational documentation (network detail, runbooks for adding/removing
nodes, recovery procedures, the private-overlay setup) lives outside this
repo.

## Quickstart from zero

1. Three Ubuntu 24.04 hosts reachable as `apex.dev01`–`03`, with the user
   `jake` in the `sudo` group, and `ssh-copy-id` already done.
2. Bring them up:
   ```bash
   make bootstrap-ansible-first
   ```
   This installs NOPASSWD sudo, baseline packages, and HA K3s. After this
   run any future ansible run uses plain `make bootstrap-ansible`.
3. Copy `/etc/rancher/k3s/k3s.yaml` from `apex.dev01` to your workstation
   `~/.kube/config` (replacing `127.0.0.1` with `192.168.1.50`) so
   `kubectl` works.
4. Install ArgoCD and bootstrap GitOps:
   ```bash
   make install-argocd
   make argocd-password    # save this somewhere
   make argocd-ui          # https://localhost:8080
   ```
5. ArgoCD now manages everything under `k8s/apps/`. New workload =
   new `Application` manifest in that directory.

See [ansible/README.md](ansible/README.md) and [k8s/README.md](k8s/README.md)
for component-level details.
