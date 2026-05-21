# Deploie le frontend COFRAP (chart cofrap-frontend) sur un cluster Kubernetes.
#
# Usage :
#   ./scripts/install.ps1
#   ./scripts/install.ps1 -IngressHost cofrap.mondomaine.fr
#   ./scripts/install.ps1 -Namespace cofrap -ImageTag 2026.1.0
#
# Pre-requis : kubectl + helm configures sur le cluster cible.
# Le backend (OpenFaaS + chart cofrap) doit etre deploye AVANT.

[CmdletBinding()]
param(
  [string]$Namespace      = 'cofrap',
  [string]$ReleaseName    = 'cofrap-frontend',
  [string]$IngressEnabled = 'true',
  [string]$IngressHost    = 'cofrap.example.com',
  [string]$IngressClass   = 'traefik',
  [string]$BackendGateway = 'gateway.openfaas.svc.cluster.local:8080',
  [string]$ImageTag       = '',
  [string]$ImageRepository = ''
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ChartPath = Join-Path $ScriptDir '..\deploy\helm\cofrap-frontend'

function Blue($m)  { Write-Host "> $m" -ForegroundColor Blue }
function Green($m) { Write-Host $m -ForegroundColor Green }

function Require($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Error "Manquant : $cmd"; exit 1
  }
}

# --- 1. Prerequis -----------------------------------------------------------
Blue 'Verification des prerequis'
Require kubectl
Require helm
kubectl cluster-info *> $null
if ($LASTEXITCODE -ne 0) { Write-Error 'kubectl ne peut pas joindre le cluster'; exit 1 }
Green 'kubectl + helm OK, cluster joignable.'

# --- 2. Install du chart cofrap-frontend ------------------------------------
Blue "Installation du chart cofrap-frontend (namespace $Namespace)"
$helmArgs = @(
  'upgrade', '--install', $ReleaseName, $ChartPath,
  '--namespace', $Namespace, '--create-namespace',
  '--set', "ingress.enabled=$IngressEnabled",
  '--set', "ingress.host=$IngressHost",
  '--set', "ingress.className=$IngressClass",
  '--set', "backend.gateway=$BackendGateway",
  '--set', 'image.pullPolicy=IfNotPresent',
  '--wait', '--timeout', '5m'
)
if ($ImageTag)        { $helmArgs += @('--set', "image.tag=$ImageTag") }
if ($ImageRepository) { $helmArgs += @('--set', "image.repository=$ImageRepository") }

helm @helmArgs
if ($LASTEXITCODE -ne 0) { Write-Error 'Echec de l''installation Helm.'; exit 1 }

# --- 3. Recapitulatif -------------------------------------------------------
Write-Host ''
Green '============================================================'
Green '  Frontend COFRAP installe'
Green '============================================================'
Write-Host ''
Write-Host "Namespace        : $Namespace"
Write-Host "Hote Ingress     : http://$IngressHost"
Write-Host "Gateway backend  : $BackendGateway"
Write-Host ''
Write-Host 'Verifier le deploiement :'
Write-Host "  kubectl -n $Namespace get pods,svc,ingress -l app.kubernetes.io/name=cofrap-frontend"
Write-Host ''
Write-Host "Desinstaller : helm uninstall $ReleaseName -n $Namespace"
Write-Host ''
