<div align="center">

# cofrap-frontend

[🇫🇷 Français](README.md) · **🇬🇧 English**

**Frontend of the COFRAP PoC** — a Vue 3 SPA for account creation, authentication and credential renewal (MSPR TPRE912).

[![Vue](https://img.shields.io/badge/Vue-3-4FC08D?logo=vuedotjs&logoColor=white)](https://vuejs.org/)
[![Vite](https://img.shields.io/badge/Vite-8-646CFF?logo=vite&logoColor=white)](https://vite.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![nginx](https://img.shields.io/badge/nginx-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)

</div>

---

## Table of contents

- [Context](#context)
- [Architecture](#architecture)
- [Views](#views)
- [Quick start](#quick-start)
- [Deployment](#deployment)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Context

Frontend of the **COFRAP** PoC (MSPR TPRE912 — serverless development project). A Vue 3 **SPA** (Single Page Application) that lets users create an account, authenticate and renew expired credentials, backed by the serverless backend functions.

> OpenFaaS backend in a separate repo. **The backend connection is not enabled in this version** — the frontend deploys and runs standalone.

## Architecture

```
┌─────────────────────────────┐         ┌──────────────────┐
│  Browser                    │  HTTP   │  nginx (K8s pod) │
│  Vue 3 SPA (static)         │ ◄─────► │  /dist           │
└─────────────────────────────┘         └──────────────────┘
```

**Stack**: Vue 3 (Composition API) · Vite · TypeScript · vue-router · Pinia · SCSS — built as static files, served by **nginx**.

The frontend is **bilingual** (FR/EN) and cares about **accessibility** (dedicated panel, audio reading, light/dark theme, OpenDyslexic font) — in line with the brief's inclusive-environment goal.

→ Details: [`docs/en/architecture.md`](docs/en/architecture.md).

## Views

`vue-router` in history mode — 4 routes:

| Path         | View             | Role                                       |
|--------------|------------------|--------------------------------------------|
| `/`          | `HomeView`       | Home                                       |
| `/login`     | `LoginView`      | Authentication of an existing user         |
| `/register`  | `RegisterView`   | Account creation (password + 2FA)          |
| `/renew`     | `RenewView`      | Renewal of expired credentials             |

## Quick start

> Prerequisites: Node.js `^20.19 || >=22.12`, Yarn classic.

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

yarn install      # dependencies
yarn dev          # dev server + HMR → http://localhost:5173
```

Production build:

```bash
yarn build        # type checking + bundle into dist/
yarn preview      # serves the built dist/ locally
```

→ Details and conventions: [`docs/en/development.md`](docs/en/development.md).

## Deployment

The app is built into a **Docker image** (nginx + static files), deployed to Kubernetes via a **Helm chart**.

```bash
# Image
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .

# Deployment (Deployment + Service + Ingress chart)
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set ingress.host=cofrap.example.com
```

→ Step-by-step guide (K3s / minikube / existing cluster): [`docs/en/installation.md`](docs/en/installation.md).

## Repository layout

```
.
├── README.md / README.en.md         # French version + this file (EN)
├── index.html                        # HTML entry point
├── package.json                      # dependencies + Yarn scripts
├── vite.config.ts                    # Vite configuration
├── Dockerfile                        # multi-stage build node → nginx
├── nginx.conf                        # nginx config (SPA fallback + /healthz)
├── src/
│   ├── views/                        # 4 views (home, login, register, renew)
│   ├── components/                   # reusable components
│   ├── composables/                  # cross-cutting logic (a11y, language, theme)
│   ├── lang/                         # FR / EN translations
│   ├── router/                       # route definitions
│   └── assets/                       # SCSS styles
├── deploy/helm/cofrap-frontend/      # Helm chart (Deployment + Service + Ingress)
└── docs/
    ├── fr/                           # French documentation
    └── en/                           # English documentation
```

## Documentation

Bilingual documentation: [`docs/fr/`](docs/fr/README.md) · [`docs/en/`](docs/en/README.md).

| Document                                          | Content                                              |
|---------------------------------------------------|------------------------------------------------------|
| [`architecture.md`](docs/en/architecture.md)      | Stack, structure, routing, i18n, accessibility       |
| [`development.md`](docs/en/development.md)         | Local setup, Yarn scripts, conventions               |
| [`deployment.md`](docs/en/deployment.md)           | Docker image, Helm chart, options                    |
| [`installation.md`](docs/en/installation.md)      | Step-by-step deployment on K3s / minikube / cluster   |
| [`troubleshooting.md`](docs/en/troubleshooting.md) | Common errors and fixes                              |

## Contributing

1. Fork + feature branch.
2. `yarn install`, then code with `yarn dev`.
3. `yarn format` + `yarn type-check` + `yarn build` (everything passes).
4. PR to `main`.

## License

[MIT](https://opensource.org/licenses/MIT) — academic project MSPR TPRE912 (EPSI / Pro Alterna).

---

<div align="center">
<sub>Built as part of the MSPR TPRE912 — EPSI / Pro Alterna · Block 2.</sub>
</div>
