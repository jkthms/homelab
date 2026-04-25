#!/usr/bin/env bash
# One-shot ArgoCD installation. Idempotent — re-running upgrades in place.
# Bump ARGOCD_VERSION and re-run to upgrade.
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.3.8}"
NAMESPACE="argocd"

echo ">> Creating namespace ${NAMESPACE}"
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 \
  || kubectl create namespace "${NAMESPACE}"

echo ">> Applying ArgoCD ${ARGOCD_VERSION} manifests"
kubectl apply -n "${NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo ">> Waiting for argocd-server to be ready"
kubectl -n "${NAMESPACE}" rollout status deploy/argocd-server --timeout=5m

echo ">> Applying root app-of-apps"
kubectl apply -f "$(dirname "$0")/root-app.yaml"

cat <<'EOF'

ArgoCD installed. Useful next steps:

  # Get the bootstrap admin password
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo

  # Port-forward the UI
  kubectl -n argocd port-forward svc/argocd-server 8080:443
  # Then open https://localhost:8080  (user: admin)

EOF
