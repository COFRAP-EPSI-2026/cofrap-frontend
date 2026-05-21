#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build l'image du frontend COFRAP.

.DESCRIPTION
    Deux modes :
      - LOCAL : build mono-architecture + import dans le cluster local
                (auto-détecte minikube / K3s / k3d / kind).
      - PUSH  : build MULTI-architecture (buildx) + push sur un registry (-Push).

.EXAMPLE
    ./scripts/prod/build-images.ps1
    ./scripts/prod/build-images.ps1 -Registry "ghcr.io/mon-org" -Push
    ./scripts/prod/build-images.ps1 -Tag dev -Push
    ./scripts/prod/build-images.ps1 -Platforms "linux/amd64,linux/arm64,linux/arm/v7" -Push
#>
[CmdletBinding()]
param(
    [string]$Registry = "ghcr.io/cofrap-epsi-2026",
    [string]$Tag = "2026.1.0",
    [string]$Platforms = "linux/amd64,linux/arm64",
    [ValidateSet("auto", "minikube", "kind", "k3d", "k3s", "generic")]
    [string]$ClusterType = "auto",
    [switch]$Push
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Join-Path $ScriptDir ".." ".."
$Image = "${Registry}/cofrap-frontend:${Tag}"

function Write-Step ($msg) { Write-Host "▸ $msg" -ForegroundColor Cyan }
function Write-Ok ($msg)   { Write-Host $msg     -ForegroundColor Green }
function Write-Warn2 ($msg){ Write-Host $msg     -ForegroundColor Yellow }
function Write-Err ($msg)  { Write-Host $msg     -ForegroundColor Red }

# ─── Mode PUSH : build multi-architecture + push (buildx) ────────────────────
if ($Push) {
    Write-Step "Build multi-architecture [$Platforms] + push : $Image"
    docker buildx inspect cofrap-builder *> $null
    if ($LASTEXITCODE -ne 0) {
        docker buildx create --name cofrap-builder --driver docker-container | Out-Null
    }
    docker buildx build --builder cofrap-builder `
        --platform $Platforms `
        --provenance=false `
        --push `
        -t $Image $Root
    if ($LASTEXITCODE -ne 0) { Write-Err "Build échoué"; exit 1 }
    Write-Ok "Image multi-arch poussée [$Platforms]."
    Write-Host ""
    Write-Host "(Re)déployer le frontend :"
    Write-Host "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values ``"
    Write-Host "    --set image.repository=${Registry}/cofrap-frontend --set image.tag=$Tag"
    exit 0
}

# ─── Mode LOCAL : build mono-arch + import dans le cluster ───────────────────
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

switch ($Cluster) {
    "minikube" {
        Write-Warn2 "Pointage du Docker CLI vers le daemon minikube"
        & minikube -p minikube docker-env --shell powershell | Invoke-Expression
    }
    "generic" {
        Write-Err "Cluster non local. Pour publier l'image, utilise -Push :"
        Write-Err "  ./scripts/prod/build-images.ps1 -Push"
        exit 1
    }
}

Write-Step "Build $Image"
docker build -t $Image $Root
if ($LASTEXITCODE -ne 0) { Write-Err "Build échoué"; exit 1 }

switch ($Cluster) {
    "minikube" { Write-Ok "Image disponible dans le daemon minikube (pas de push nécessaire)." }
    "k3s" {
        Write-Step "Import de l'image dans containerd (K3s)"
        docker save $Image | sudo k3s ctr images import -
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
}

Write-Host ""
Write-Host "(Re)déployer le frontend :"
Write-Host "  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap --reuse-values ``"
Write-Host "    --set image.repository=${Registry}/cofrap-frontend --set image.tag=$Tag --set image.pullPolicy=IfNotPresent"
Write-Host "  kubectl -n cofrap rollout restart deployment -l app.kubernetes.io/name=cofrap-frontend"
