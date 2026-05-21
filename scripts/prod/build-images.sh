#!/usr/bin/env bash
# Build l'image du frontend COFRAP.
#
# Deux modes :
#   - LOCAL : build mono-architecture + import dans le cluster local
#             (auto-détecte minikube / K3s / k3d / kind). Pas de registry.
#   - PUSH  : build MULTI-architecture (buildx) + push sur un registry.
#
# Usage :
#   ./scripts/prod/build-images.sh                                  # local, auto-détection
#   PUSH=1 ./scripts/prod/build-images.sh                           # build multi-arch + push GHCR
#   REGISTRY=ghcr.io/mon-org PUSH=1 ./scripts/prod/build-images.sh  # autre registry
#   TAG=dev PUSH=1 ./scripts/prod/build-images.sh                   # tag custom
#   PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7 PUSH=1 ...        # architectures custom

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."

REGISTRY="${REGISTRY:-ghcr.io/cofrap-epsi-2026}"
TAG="${TAG:-2026.1.0}"
PUSH="${PUSH:-0}"
CLUSTER_TYPE="${CLUSTER_TYPE:-auto}"
# Architectures du build multi-arch (mode PUSH uniquement).
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

IMAGE="${REGISTRY}/cofrap-frontend:${TAG}"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m> %s\033[0m\n' "$*"; }

# --- Mode PUSH : build multi-architecture + push (buildx) -------------------
if [ "$PUSH" = "1" ]; then
  blue "Build multi-architecture [$PLATFORMS] + push : $IMAGE"
  # Le multi-plateforme exige un builder buildx « docker-container ».
  # Sur Linux nu, si l'émulation cross-arch manque, lancer une fois :
  #   docker run --privileged --rm tonistiigi/binfmt --install all
  docker buildx inspect cofrap-builder >/dev/null 2>&1 \
    || docker buildx create --name cofrap-builder --driver docker-container >/dev/null
  docker buildx build --builder cofrap-builder \
    --platform "$PLATFORMS" \
    --provenance=false \
    --push \
    -t "$IMAGE" "$ROOT"
  green "✓ Image multi-arch poussée [$PLATFORMS]."
  echo
  echo "(Re)déployer le frontend :"
  echo "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values \\"
  echo "    --set image.repository=${REGISTRY}/cofrap-frontend --set image.tag=${TAG}"
  exit 0
fi

# --- Mode LOCAL : build mono-arch + import dans le cluster ------------------
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
blue "Cluster détecté : $CLUSTER"

case "$CLUSTER" in
  minikube)
    yellow "Pointage du Docker CLI vers le daemon de minikube"
    eval "$(minikube -p minikube docker-env --shell bash)"
    ;;
  generic)
    red "Cluster non local. Pour publier l'image, utilise le mode PUSH :"
    red "  PUSH=1 $0"
    exit 1
    ;;
esac

blue "Build $IMAGE"
docker build -t "$IMAGE" "$ROOT"

case "$CLUSTER" in
  minikube)
    green "✓ Image disponible dans le daemon minikube (pas de push nécessaire)."
    ;;
  k3s)
    blue "Import de l'image dans containerd (K3s)"
    docker save "$IMAGE" | sudo k3s ctr images import -
    green "✓ Image importée dans K3s."
    ;;
  k3d)
    blue "Import de l'image dans K3d"
    k3d image import "$IMAGE" -c "$(kubectl config current-context | sed 's/^k3d-//')"
    green "✓ Image importée dans K3d."
    ;;
  kind)
    blue "Import de l'image dans KinD"
    kind load docker-image "$IMAGE"
    green "✓ Image importée dans KinD."
    ;;
esac

echo
echo "(Re)déployer le frontend :"
echo "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values \\"
echo "    --set image.repository=${REGISTRY}/cofrap-frontend --set image.tag=${TAG} --set image.pullPolicy=IfNotPresent"
echo "  kubectl -n cofrap rollout restart deployment -l app.kubernetes.io/name=cofrap-frontend"
