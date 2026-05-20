# Deployment

The frontend is deployed in two steps: **build an image** (nginx + static build), then **install it** on Kubernetes via the Helm chart.

> Cluster quickstart (K3s / minikube / existing cluster): [`installation.md`](installation.md).

## 1. Docker image

The [`Dockerfile`](../../Dockerfile) is **multi-stage**:

1. **Build stage** — `node:22-alpine`: `yarn install --frozen-lockfile` then `yarn build` → `dist/`.
2. **Runtime stage** — `nginxinc/nginx-unprivileged`: copies `dist/` into `/usr/share/nginx/html` + the [`nginx.conf`](../../nginx.conf) config.

The final image contains **no** Node: just nginx + the static files. It runs **non-root** (UID 101) and listens on port **8080**.

```bash
# Build
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .

# Local test
docker run --rm -p 8080:8080 ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
# → http://127.0.0.1:8080

# Push (after docker login ghcr.io)
docker push ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
```

### nginx.conf

Key points of [`nginx.conf`](../../nginx.conf):

- **SPA fallback**: `try_files $uri $uri/ /index.html` — essential because `vue-router` is in history mode (without it, reloading `/login` yields a 404).
- **Asset caching**: `/assets/*` files (hashed names from Vite) are cached for 1 year, `immutable`.
- **`/healthz`**: probe endpoint returning `200 ok`, used by the Docker `HEALTHCHECK` and the Kubernetes probes.

## 2. Helm chart

The [`deploy/helm/cofrap-frontend`](../../deploy/helm/cofrap-frontend) chart deploys 3 resources:

| Resource     | Role                                                          |
|--------------|---------------------------------------------------------------|
| `Deployment` | nginx pod(s) serving the SPA                                  |
| `Service`    | `ClusterIP`, exposes the pod internally (port 80 → 8080)      |
| `Ingress`    | Exposes the frontend outside the cluster (can be disabled)    |

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=2026.1.0 \
  --set ingress.host=cofrap.example.com \
  --set ingress.className=traefik
```

### Main values

| Key                   | Default                                      | Description                                   |
|-----------------------|----------------------------------------------|-----------------------------------------------|
| `image.repository`    | `ghcr.io/cofrap-epsi-2026/cofrap-frontend`   | SPA image                                     |
| `image.tag`           | `2026.1.0`                                   | Image tag                                     |
| `replicaCount`        | `1`                                          | Number of replicas                           |
| `ingress.enabled`     | `true`                                       | Create the Ingress                           |
| `ingress.className`   | `traefik`                                    | Target IngressClass (`""` = default class)    |
| `ingress.host`        | `cofrap.example.com`                         | Exposed hostname                             |
| `ingress.tls.enabled` | `false`                                      | Enable TLS                                   |

Full list: [`deploy/helm/cofrap-frontend/values.yaml`](../../deploy/helm/cofrap-frontend/values.yaml).

## Scope of this version

- The frontend is deployed **standalone**: no backend connection is configured (no `/api` proxy, no backend environment variable).
- Wiring the frontend ↔ OpenFaaS backend will be added in a later version.
