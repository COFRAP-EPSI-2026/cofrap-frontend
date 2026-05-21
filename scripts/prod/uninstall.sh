#!/usr/bin/env bash
# Désinstalle le frontend COFRAP (release Helm cofrap-frontend).
#
# Usage :
#   ./scripts/prod/uninstall.sh
#   NAMESPACE=cofrap RELEASE_NAME=cofrap-frontend ./scripts/prod/uninstall.sh
#
# Ne supprime QUE la release du frontend. Le namespace `cofrap` et le backend
# (MariaDB, fonctions) ne sont PAS touchés — pour ça, voir le script
# uninstall du dépôt cofrap-backend.

set -euo pipefail

NAMESPACE="${NAMESPACE:-cofrap}"
RELEASE_NAME="${RELEASE_NAME:-cofrap-frontend}"

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

# --- 2. Désinstallation -----------------------------------------------------
blue "Désinstallation de la release ${RELEASE_NAME} (namespace ${NAMESPACE})"
if helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
  green "Release ${RELEASE_NAME} désinstallée."
else
  red "Aucune release ${RELEASE_NAME} dans le namespace ${NAMESPACE} — rien à faire."
fi

# --- 3. Recapitulatif -------------------------------------------------------
echo
echo "Le namespace ${NAMESPACE} et le backend (MariaDB, fonctions) ne sont PAS touchés."
echo "Désinstaller le backend : scripts/prod/uninstall.sh du dépôt cofrap-backend."
echo
