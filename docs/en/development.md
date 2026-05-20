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
| `yarn preview`     | Serves the already-built `dist/` locally (check the prod rendering)     |
| `yarn format`      | Formats `src/` with Prettier                                            |

## Code conventions

- **TypeScript** everywhere — `.vue` files use `<script setup lang="ts">`.
- Vue 3 **Composition API**; cross-cutting logic lives in `src/composables/`.
- **Prettier** for formatting (`.prettierrc.json`). Run `yarn format` before committing.
- Import alias **`@`** → `src/` (configured in `vite.config.ts` and `tsconfig`). E.g. `import HomeView from '@/views/HomeView.vue'`.
- Displayed strings go through the language files `src/lang/{fr,en}.ts` — never hard-code text in components.

## Typical dev cycle

1. `yarn dev` and code.
2. `yarn format` for formatting.
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

The frontend calls the backend via `/api` (a relative path). In dev, the Vite server proxies `/api` to the OpenFaaS gateway (see `server.proxy` in `vite.config.ts`, target `http://127.0.0.1:8080`).

For this to work, expose the OpenFaaS gateway on port 8080 **before** `yarn dev`:

```bash
kubectl -n openfaas port-forward svc/gateway 8080:8080
```

Then `yarn dev`: the frontend's calls to `/api/function/<name>` reach the gateway. No CORS (Vite serves everything from the same origin `localhost:5173`).

If the port-forward is not running, the app still loads but API calls fail — that is expected.

## Test the Docker image locally

```bash
docker build -t cofrap-frontend:dev .
docker run --rm -p 8080:8080 cofrap-frontend:dev
# → http://127.0.0.1:8080
```

> With no cluster behind it, the container's `/api` proxy won't reach a gateway — only the SPA is testable this way.

→ Image + deployment details: [`deployment.md`](deployment.md).

## Common issues

See [`troubleshooting.md`](troubleshooting.md).
