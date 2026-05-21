# Désinstalle le frontend COFRAP (release Helm cofrap-frontend).
#
# Usage :
#   ./scripts/prod/uninstall.ps1
#   ./scripts/prod/uninstall.ps1 -Namespace cofrap -ReleaseName cofrap-frontend
#
# Ne supprime QUE la release du frontend. Le namespace `cofrap` et le backend
# (MariaDB, fonctions) ne sont PAS touchés.

[CmdletBinding()]
param(
  [string]$Namespace   = 'cofrap',
  [string]$ReleaseName = 'cofrap-frontend'
)

$ErrorActionPreference = 'Stop'

function Blue($m)  { Write-Host "> $m" -ForegroundColor Blue }
function Green($m) { Write-Host $m -ForegroundColor Green }
function Red($m)   { Write-Host $m -ForegroundColor Red }

function Require($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Error "Manquant : $cmd"; exit 1
  }
}

# --- 1. Prerequis -----------------------------------------------------------
Blue 'Vérification des prérequis'
Require kubectl
Require helm
kubectl cluster-info *> $null
if ($LASTEXITCODE -ne 0) { Write-Error 'kubectl ne peut pas joindre le cluster'; exit 1 }
Green 'kubectl + helm OK, cluster joignable.'

# --- 2. Désinstallation -----------------------------------------------------
Blue "Désinstallation de la release $ReleaseName (namespace $Namespace)"
helm status $ReleaseName -n $Namespace *> $null
if ($LASTEXITCODE -eq 0) {
  helm uninstall $ReleaseName -n $Namespace
  Green "Release $ReleaseName désinstallée."
} else {
  Red "Aucune release $ReleaseName dans le namespace $Namespace - rien à faire."
}

# --- 3. Recapitulatif -------------------------------------------------------
Write-Host ''
Write-Host "Le namespace $Namespace et le backend (MariaDB, fonctions) ne sont PAS touchés."
Write-Host 'Désinstaller le backend : scripts/prod/uninstall.ps1 du dépôt cofrap-backend.'
Write-Host ''
