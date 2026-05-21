#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build l'image du frontend COFRAP et la rend disponible dans le cluster local.

.DESCRIPTION
    Auto-détecte minikube / K3s / kind / Docker Desktop. Pour les clusters distants,
    push sur le registry de ton choix avec -Push.

.EXAMPLE
    ./scripts/build-images.ps1
    ./scripts/build-images.ps1 -Registry "ghcr.io/mon-org" -Push
    ./scripts/build-images.ps1 -Tag dev
#>
[CmdletBinding()]
param(
    [string]$Registry = "ghcr.io/cofrap-epsi-2026",
    [string]$Tag = "2026.1.0",  # x-release-please-version
    [ValidateSet("auto", "minikube", "kind", "k3d", "k3s", "generic")]
    [string]$ClusterType = "auto",
    [switch]$Push
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Join-Path $ScriptDir ".."

$Image = "${Registry}/cofrap-frontend:${Tag}"

function Write-Step ($msg) { Write-Host "▸ $msg" -ForegroundColor Cyan }
function Write-Ok ($msg) { Write-Host $msg     -ForegroundColor Green }
function Write-Warn2 ($msg) { Write-Host $msg     -ForegroundColor Yellow }
function Write-Err ($msg) { Write-Host $msg     -ForegroundColor Red }

# ─── Détection du cluster ───────────────────────────────────────────────────
function Detect-Cluster {
    if ($ClusterType -ne "auto") { return $ClusterType }
    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        & minikube status *> $null
        if ($LASTEXITCODE -eq 0) { return "minikube" }
    }
    $ctx = (kubectl config current-context 2>$null)
    if ($ctx -like "*kind*") { return "kind" }
    if ($ctx -like "*k3d*") { return "k3d" }
    if (Get-Command k3s -ErrorAction SilentlyContinue) { return "k3s" }
    return "generic"
}

$Cluster = Detect-Cluster
Write-Step "Cluster détecté : $Cluster"

# ─── Configuration du daemon Docker ─────────────────────────────────────────
switch ($Cluster) {
    "minikube" {
        Write-Warn2 "Pointage du Docker CLI vers le daemon minikube"
        & minikube -p minikube docker-env --shell powershell | Invoke-Expression
    }
    "generic" {
        if (-not $Push) {
            Write-Err "Cluster non local détecté. Pour pousser sur un registry :"
            Write-Err "  ./scripts/build-images.ps1 -Registry ghcr.io/mon-org -Push"
            exit 1
        }
    }
}

# ─── Build ──────────────────────────────────────────────────────────────────
Write-Step "Build $Image"
docker build -t $Image $Root
if ($LASTEXITCODE -ne 0) { Write-Err "Build échoué"; exit 1 }

# ─── Distribution ───────────────────────────────────────────────────────────
switch ($Cluster) {
    "minikube" {
        Write-Ok "Image disponible dans le daemon minikube (pas de push nécessaire)."
    }
    "k3s" {
        Write-Step "Import de l'image dans containerd (K3s)"
        docker save $Image | k3s ctr images import -
        Write-Ok "Image importée dans K3s."
    }
    "k3d" {
        Write-Step "Import de l'image dans K3d"
        $clusterName = (kubectl config current-context) -replace "^k3d-", ""
        & k3d image import $Image -c $clusterName
        Write-Ok "Image importée dans K3d."
    }
    "kind" {
        Write-Step "Import de l'image dans KinD"
        & kind load docker-image $Image
        Write-Ok "Image importée dans KinD."
    }
    "generic" {
        if ($Push) {
            Write-Step "Push vers $Registry"
            docker push $Image
            Write-Ok "Image poussée."
        }
    }
}

Write-Host ""
Write-Host "Pour (re)déployer le frontend avec cette image :"
Write-Host "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values ``"
Write-Host "    --set image.repository=${Registry}/cofrap-frontend ``"
Write-Host "    --set image.tag=$Tag ``"
Write-Host "    --set image.pullPolicy=IfNotPresent"
Write-Host ""
Write-Host "Puis forcer le redéploiement (sinon K8s garde les anciens pods sans pull) :"
Write-Host "  kubectl -n cofrap rollout restart deployment -l app.kubernetes.io/name=cofrap-frontend"
