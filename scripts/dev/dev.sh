#!/usr/bin/env bash
# Lance le frontend COFRAP en développement local (Vite + HMR sur :5173).
#
# Usage : ./scripts/dev/dev.sh
#
# Le frontend appelle le backend via /api → un backend doit écouter sur
# http://127.0.0.1:8080 : stack docker-compose du dépôt cofrap-backend
# (./scripts/dev/stack.sh up), ou `kubectl port-forward` du gateway OpenFaaS.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

yarn install
yarn dev
