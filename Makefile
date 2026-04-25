# Thin wrappers around the homelab IaC. Targets are deliberately small —
# they're shortcuts, not abstractions.

.PHONY: help bootstrap-ansible bootstrap-ansible-first install-argocd argocd-password argocd-ui

help:
	@echo "homelab targets:"
	@echo "  bootstrap-ansible-first  ansible bootstrap with --ask-become-pass (use on fresh hosts)"
	@echo "  bootstrap-ansible        ansible bootstrap (NOPASSWD already in place)"
	@echo "  install-argocd           install ArgoCD + apply root app-of-apps"
	@echo "  argocd-password          print the initial admin password"
	@echo "  argocd-ui                port-forward the ArgoCD UI to https://localhost:8080"

bootstrap-ansible-first:
	cd ansible && ansible-playbook bootstrap.yml --ask-become-pass

bootstrap-ansible:
	cd ansible && ansible-playbook bootstrap.yml

install-argocd:
	bash k8s/bootstrap/install-argocd.sh

argocd-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

argocd-ui:
	kubectl -n argocd port-forward svc/argocd-server 8080:443
