#!/usr/bin/env bash
# Deploie le frontend COFRAP (chart cofrap-frontend) sur un cluster Kubernetes.
#
# Usage :
#   ./scripts/prod/install.sh                                       # defauts
#   INGRESS_HOST=cofrap.mondomaine.fr ./scripts/prod/install.sh     # hote Ingress
#   INGRESS_ENABLED=false ./scripts/prod/install.sh                 # pas d'Ingress
#   NAMESPACE=cofrap IMAGE_TAG=2026.1.0 ./scripts/prod/install.sh   # overrides
#
# INGRESS_ENABLED=false : utile derriere un Cloudflare Tunnel (ou autre proxy)
# qui pointe directement sur le Service cofrap-frontend — l'Ingress est inutile.
#
# Pre-requis : kubectl + helm configures sur le cluster cible.
# Le backend (OpenFaaS + chart cofrap) doit etre deploye AVANT.

set -euo pipefail

NAMESPACE="${NAMESPACE:-cofrap}"
RELEASE_NAME="${RELEASE_NAME:-cofrap-frontend}"
INGRESS_ENABLED="${INGRESS_ENABLED:-true}"
INGRESS_HOST="${INGRESS_HOST:-cofrap.example.com}"
INGRESS_CLASS="${INGRESS_CLASS:-traefik}"
BACKEND_GATEWAY="${BACKEND_GATEWAY:-gateway.openfaas.svc.cluster.local:8080}"
IMAGE_TAG="${IMAGE_TAG:-}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_PATH="${SCRIPT_DIR}/../../deploy/helm/cofrap-frontend"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m> %s\033[0m\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { red "Manquant : $1"; exit 1; }; }

# --- 1. Prerequis -----------------------------------------------------------
blue "Vérification des prérequis"
require kubectl
require helm
kubectl cluster-info >/dev/null || { red "kubectl ne peut pas joindre le cluster"; exit 1; }
green "kubectl + helm OK, cluster joignable."

# --- 2. Install du chart cofrap-frontend ------------------------------------
blue "Installation du chart cofrap-frontend (namespace ${NAMESPACE})"
HELM_ARGS=(
  upgrade --install "$RELEASE_NAME" "$CHART_PATH"
  --namespace "$NAMESPACE" --create-namespace
  --set "ingress.enabled=${INGRESS_ENABLED}"
  --set "ingress.host=${INGRESS_HOST}"
  --set "ingress.className=${INGRESS_CLASS}"
  --set "backend.gateway=${BACKEND_GATEWAY}"
  --set "image.pullPolicy=IfNotPresent"
  --wait --timeout 5m
)
[ -n "$IMAGE_TAG" ]        && HELM_ARGS+=(--set "image.tag=${IMAGE_TAG}")
[ -n "$IMAGE_REPOSITORY" ] && HELM_ARGS+=(--set "image.repository=${IMAGE_REPOSITORY}")

helm "${HELM_ARGS[@]}"

# --- 3. Recapitulatif -------------------------------------------------------
echo
green "============================================================"
green "  Frontend COFRAP installe"
green "============================================================"
echo
echo "Namespace        : ${NAMESPACE}"
echo "Hote Ingress     : http://${INGRESS_HOST}"
echo "Gateway backend  : ${BACKEND_GATEWAY}"
echo
echo "Verifier le deploiement :"
echo "  kubectl -n ${NAMESPACE} get pods,svc,ingress -l app.kubernetes.io/name=cofrap-frontend"
echo
echo "Si l'hote n'est pas dans un DNS, l'ajouter au /etc/hosts du poste de test :"
echo "  <IP-du-node-k3s>  ${INGRESS_HOST}"
echo
echo "Desinstaller : helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}"
echo
