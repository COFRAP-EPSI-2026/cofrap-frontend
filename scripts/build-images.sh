#!/usr/bin/env bash
# Build l'image du frontend COFRAP et la rend disponible dans le cluster local
# SANS passer par un registry distant.
#
# Auto-detecte minikube / K3s / k3d / kind. Pour un cluster distant, builde puis
# pousse sur le registry de ton choix (REGISTRY=... PUSH=1).
#
# Usage :
#   ./scripts/build-images.sh                                  # auto-detection
#   REGISTRY=ghcr.io/mon-org PUSH=1 ./scripts/build-images.sh   # build + push
#   TAG=dev ./scripts/build-images.sh                          # tag custom
#
# A lancer sur la machine qui heberge le cluster (l'import K3s/containerd est local).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."

REGISTRY="${REGISTRY:-ghcr.io/cofrap-epsi-2026}"
TAG="${TAG:-2026.1.0}"
PUSH="${PUSH:-0}"
CLUSTER_TYPE="${CLUSTER_TYPE:-auto}"

IMAGE="${REGISTRY}/cofrap-frontend:${TAG}"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m> %s\033[0m\n' "$*"; }

# --- Detection du cluster ---------------------------------------------------
detect_cluster() {
  if [ "$CLUSTER_TYPE" != "auto" ]; then echo "$CLUSTER_TYPE"; return; fi
  if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
    echo "minikube"; return
  fi
  local ctx
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  case "$ctx" in
    *kind*) echo "kind"; return ;;
    *k3d*)  echo "k3d"; return ;;
    *)      if command -v k3s >/dev/null 2>&1; then echo "k3s"; return; fi ;;
  esac
  echo "generic"
}

CLUSTER="$(detect_cluster)"
blue "Cluster detecte : $CLUSTER"

# --- Configuration du daemon Docker selon le cluster ------------------------
case "$CLUSTER" in
  minikube)
    yellow "Pointage du Docker CLI vers le daemon de minikube"
    eval "$(minikube -p minikube docker-env --shell bash)"
    ;;
  generic)
    if [ "$PUSH" != "1" ]; then
      red "Cluster non local detecte. Pour pousser sur un registry :"
      red "  REGISTRY=ghcr.io/mon-org PUSH=1 $0"
      exit 1
    fi
    ;;
esac

# --- Build de l'image -------------------------------------------------------
blue "Build $IMAGE"
docker build -t "$IMAGE" "$ROOT"

# --- Distribution selon le cluster ------------------------------------------
case "$CLUSTER" in
  minikube)
    green "OK : image disponible dans le daemon minikube (pas de push necessaire)."
    ;;
  k3s)
    blue "Import de l'image dans containerd (K3s)"
    docker save "$IMAGE" | sudo k3s ctr images import -
    green "OK : image importee dans K3s."
    ;;
  k3d)
    blue "Import de l'image dans K3d"
    k3d image import "$IMAGE" -c "$(kubectl config current-context | sed 's/^k3d-//')"
    green "OK : image importee dans K3d."
    ;;
  kind)
    blue "Import de l'image dans KinD"
    kind load docker-image "$IMAGE"
    green "OK : image importee dans KinD."
    ;;
  generic)
    if [ "$PUSH" = "1" ]; then
      blue "Push vers $REGISTRY"
      docker push "$IMAGE"
      green "OK : image poussee."
    fi
    ;;
esac

echo
echo "Pour (re)deployer le frontend avec cette image :"
echo "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values \\"
echo "    --set image.repository=${REGISTRY}/cofrap-frontend \\"
echo "    --set image.tag=${TAG} \\"
echo "    --set image.pullPolicy=IfNotPresent"
echo
echo "Puis forcer le redeploiement (sinon K8s garde l'ancien pod sans pull) :"
echo "  kubectl -n cofrap rollout restart deployment -l app.kubernetes.io/name=cofrap-frontend"
