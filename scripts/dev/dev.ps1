# Lance le frontend COFRAP en développement local (Vite + HMR sur :5173).
#
# Usage : ./scripts/dev/dev.ps1
#
# Le frontend appelle le backend via /api → un backend doit écouter sur
# http://127.0.0.1:8080 : stack docker-compose du dépôt cofrap-backend,
# ou `kubectl port-forward` du gateway OpenFaaS.

$ErrorActionPreference = 'Stop'
$Root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".." ".."
Set-Location $Root

yarn install
yarn dev
