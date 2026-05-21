# Local development

## Prerequisites

- **Node.js** `^20.19` or `>= 22.12` (see `engines` in `package.json`)
- **Yarn** classic (1.x)
- A modern browser

## Initial setup

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

# Install dependencies
yarn install
```

## Run in development

```bash
yarn dev
```

Vite starts a dev server with **HMR** (hot module replacement) — by default on `http://localhost:5173`. Any change to a `.vue` / `.ts` file is reflected instantly.

## Yarn scripts

| Script             | Effect                                                                  |
|--------------------|--------------------------------------------------------------------------|
| `yarn dev`         | Vite dev server + HMR                                                   |
| `yarn build`       | Type checking (`vue-tsc`) **then** production build (`dist/`)            |
| `yarn build-only`  | Production build without type checking                                  |
| `yarn type-check`  | TypeScript checking only (`vue-tsc --build`)                            |
| `yarn lint`        | ESLint analysis of `.ts` / `.vue` (`yarn lint --fix` to auto-fix)       |
| `yarn preview`     | Serves the already-built `dist/` locally (check the prod rendering)     |
| `yarn format`      | Formats `src/` with Prettier                                            |
| `yarn format:check`| Checks formatting without modifying files (used by CI)                  |

## Code conventions

- **TypeScript** everywhere — `.vue` files use `<script setup lang="ts">`.
- Vue 3 **Composition API**; cross-cutting logic lives in `src/composables/`.
- **ESLint** (`eslint.config.js` — Vue + TypeScript rules) for code quality. Run `yarn lint`.
- **Prettier** for formatting (`.prettierrc.json`). Run `yarn format` before committing.
- Import alias **`@`** → `src/` (configured in `vite.config.ts` and `tsconfig`). E.g. `import HomeView from '@/views/HomeView.vue'`.
- Displayed strings go through the language files `src/lang/{fr,en}.ts` — never hard-code text in components.

## Typical dev cycle

1. `yarn dev` and code.
2. `yarn lint` + `yarn format` — code quality and formatting.
3. `yarn type-check` — no type errors.
4. `yarn build` — the production build passes.
5. Commit + PR.

## Check the production rendering locally

```bash
yarn build
yarn preview
```

`yarn preview` serves `dist/` on a local port — this is the exact content nginx will serve in production.

## Working with the backend locally

The frontend calls the backend via `/api` (a relative path). In dev, Vite proxies
`/api` to `http://127.0.0.1:8080` (see `server.proxy` in `vite.config.ts`). So you
just need the backend reachable on port 8080 — two ways:

### Option A — the backend `docker compose` stack (recommended, no cluster)

The backend repo ships a `docker-compose.yml` that starts MariaDB, the 3 functions
and a Traefik exposing the gateway on `http://localhost:8080`:

```bash
# in the cofrap-backend repo
docker compose up -d --build
```

Then, on the frontend side: `yarn dev`. Calls to `/api/function/<name>` flow
through the Vite proxy → Traefik → function. No cluster needed, no CORS (same
origin `localhost:5173`).

### Option B — an OpenFaaS cluster gateway

If the backend already runs on a cluster, expose its gateway on port 8080:

```bash
kubectl -n openfaas port-forward svc/gateway 8080:8080
```

If nothing listens on port 8080, the app still loads but API calls fail — that is expected.

## Test the Docker image locally

```bash
docker build -t cofrap-frontend:dev .
docker run --rm -p 8080:8080 cofrap-frontend:dev
# → http://127.0.0.1:8080
```

> With no cluster behind it, the container's `/api` proxy won't reach a gateway — only the SPA is testable this way.

→ Image + deployment details: [`deployment.md`](deployment.md).

## Continuous integration and pre-releases

Three GitHub Actions workflows, easy to follow:

| Workflow | Trigger | Role |
|----------|---------|------|
| `ci.yml` | PR to `dev` or `main` | **Validation**: `lint` → `format:check` → `type-check` → `build` → image build (no push) |
| `pre-release.yml` | push to `dev` | Replays `ci.yml`; if green, **publishes the `:dev` image** (+ `:dev-<sha>`) to GHCR |
| `release-please.yml` | push to `main` | **Stable release** (see below) |

Reproduce validation locally: `yarn lint && yarn format:check && yarn type-check && yarn build`.

## Releases (Release Please)

Versioning is **calendar-based** (`YYYY.MINOR.PATCH`) and **automated** by
[Release Please](https://github.com/googleapis/release-please), like the backend:

- Push [Conventional](https://www.conventionalcommits.org/) commits
  (`feat:` → minor bump, `fix:` → patch bump) to `main`.
- Release Please maintains a "Release PR" that bumps `package.json`,
  `Chart.yaml`, `values.yaml` and `CHANGELOG.md`.
- Merging that PR creates the `vX.Y.Z` tag + the GitHub Release, then
  `.github/workflows/release-please.yml` builds and pushes the image to GHCR.

**Never** bump the version by hand. Version-bearing files: `package.json` (auto),
`deploy/helm/cofrap-frontend/Chart.yaml` (×2) and
`deploy/helm/cofrap-frontend/values.yaml` (annotated `# x-release-please-version`).

One-time prerequisite: Settings → Actions → General → Workflow permissions →
tick "Allow GitHub Actions to create and approve pull requests".

## Common issues

See [`troubleshooting.md`](troubleshooting.md).
