# Troubleshooting

## Development

### `yarn install` fails

Check the Node version: `node --version` must satisfy `^20.19 || >=22.12` (the `engines` field of `package.json`). Otherwise, install a compatible version (nvm, fnm, or the official installer).

### `yarn build` fails on a type error

The build runs `vue-tsc` (TypeScript checking) before bundling. Run `yarn type-check` alone to isolate the error. A type error must be fixed — it blocks the production build.

### The dev server does not hot-reload (HMR broken)

Restart `yarn dev`. If the issue persists, clear the Vite cache: `rm -rf node_modules/.vite`.

## Docker image

### The Docker build is very slow

The `yarn install` stage re-runs whenever `package.json`/`yarn.lock` change. As long as those files don't change, the Docker cache is reused. Don't invalidate that cache needlessly (order of the `COPY` steps in the `Dockerfile`).

### `403` or blank page when the container starts

Check that `yarn build` actually produced `dist/` during the image build. Test: `docker run --rm -p 8080:8080 <image>` then open `http://127.0.0.1:8080`.

## Kubernetes deployment

### Reloading `/login` → nginx 404

The SPA fallback is not active. Check that [`default.conf.template`](../../default.conf.template) contains `try_files $uri $uri/ /index.html;` and that it is copied into the image (`COPY default.conf.template /etc/nginx/templates/default.conf.template`).

### Pod in `ImagePullBackOff`

The image is not available to the cluster. Either build it locally and load it (see [`installation.md`](installation.md)), or publish it to GHCR. Remember `--set image.pullPolicy=IfNotPresent` for a locally loaded image.

### Ingress created but the site is unreachable

1. Check that **Traefik** is running (`kubectl get pods -A | grep traefik`). It is bundled with K3s; on minikube/other clusters install it via its Helm chart.
2. Check that `ingress.className` (`traefik` by default) matches the IngressClass exposed by Traefik (`kubectl get ingressclass`).
3. Without DNS, add the `host` to `/etc/hosts` pointing to the ingress IP.
4. minikube: `minikube tunnel` must be running to expose Traefik's LoadBalancer.

### The pod keeps restarting (`CrashLoopBackOff`)

Check the logs: `kubectl -n cofrap logs -l app.kubernetes.io/name=cofrap-frontend`. nginx-unprivileged listens on **8080** — make sure the `containerPort`, the Service `targetPort` and the probes all point to 8080 / `http`.

### The probes fail

Probes hit `/healthz`. That endpoint is defined in `default.conf.template` (`location = /healthz`). If it was removed, the probes fail — restore it or adjust `probes.path` in the chart values.

## Public exposure (Cloudflare Tunnel)

### `ERR_SSL_VERSION_OR_CIPHER_MISMATCH` on the public hostname

In the Cloudflare Zero Trust dashboard, check that **Public hostname → Path is EMPTY**. A value (e.g. an `^/blog` inherited from another tunnel) restricts the tunnel to a specific path and everything else falls through → generic TLS error. The Path field must stay completely empty to serve the root.

### The tunnel points at the private IP but nothing answers

Three common causes:

1. **No stable VIP**: if the multi-node K3s cluster runs with the default ServiceLB, each node binds the port — the tunnel ends up pointing to an IP only valid on one node. Install **MetalLB** (see [`installation.md`](installation.md)) and point at the VIP.
2. **Wrong ingress class**: `kubectl get ingress -A` must show your Ingress with a non-empty `ADDRESS`. If it is empty, check `kubectl get ingressclass`.
3. **A manual Cloudflare DNS A record on top**: an A record pointing straight at the private IP short-circuits the tunnel. Everything should go through the public hostname auto-managed by the tunnel (proxied CNAME).

### `denied` / `unauthorized` on deploy (GHCR image not found)

A public repo does not automatically make the OCI **package** public. Go to `https://github.com/orgs/<org>/packages/container/cofrap-frontend/settings` → **Change package visibility** → Public. Done **once** after the very first Release Please push.

## Lighthouse — acceptable warnings

The following Lighthouse audits may surface as `warn` in the HTML report without being real bugs — documented here to avoid a fruitless chase:

### `bf-cache` — "Page prevented back/forward cache restoration"

Only happens with the **`vite preview` server** used in CI (which likely sends anti-cache headers). Application code installs no `beforeunload`/`unload`/`pagehide` listener, no Service Worker, and no open connections (WebSocket, SSE). In real production behind nginx, bf-cache works correctly (no `Cache-Control: no-store` header in `default.conf.template`).

### `errors-in-console` — "Browser errors were logged to the console"

False positive when CI runs `vite preview` **without a reachable backend**: any interaction hitting `/api/...` produces a network error logged by the browser itself (not by our code — `openfaasApi.ts` catches everything via `try/catch`). In CI we only audit `/` and `/login`, which trigger no API call on mount, so it should stay at 0. If it surfaces anyway: check that a freshly added component isn't doing a fetch on mount.

### `render-blocking-insight`, `network-dependency-tree-insight`

Tier 2 optimisations (async chunks, fonts on demand). `jsqr` and OpenDyslexic are already off the critical path — see [`architecture.md#performance--seo`](architecture.md). A new round of optimisation (HTTP/2 push, critical CSS) is not warranted for the PoC scope.

## Password display (jsqr QR)

### The "Reveal" button shows `?` or nothing

`jsQR()` failed to decode the PNG. Possible causes:

- The PNG is rendered too small/too large via CSS → the `ImageData` extracted from the `<canvas>` is degraded. Make sure the decoding source `<canvas>` uses the **native** PNG size (read `naturalWidth`/`naturalHeight` after `img.onload`).
- The QR was truncated over the wire (proxy, mis-pasted base64). Try a `curl` direct and an external QR viewer.
- On the frontend side, open the console: `jsQR` returns `null` when it finds nothing — a `console.warn` should flag it.
