# Deployment

The frontend is deployed in two steps: **build an image** (nginx + static build), then **install it** on Kubernetes via the Helm chart.

> Cluster quickstart (K3s / minikube / existing cluster): [`installation.md`](installation.md).

## 1. Docker image

The [`Dockerfile`](../../Dockerfile) is **multi-stage**:

1. **Build stage** — `node:22-alpine`: `yarn install --frozen-lockfile` then `yarn build` → `dist/`.
2. **Runtime stage** — `nginxinc/nginx-unprivileged`: copies `dist/` into `/usr/share/nginx/html` + the [`default.conf.template`](../../default.conf.template) template.

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

### nginx config

[`default.conf.template`](../../default.conf.template) is a **template**: `envsubst` substitutes `${OPENFAAS_GATEWAY}` at container startup (the `NGINX_ENVSUBST_FILTER=^OPENFAAS_` filter preserves native nginx variables). Key points:

- **`/api/*` proxy**: proxies to `${OPENFAAS_GATEWAY}` (the OpenFaaS gateway). See [Backend connection](#backend-connection).
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
| `backend.gateway`     | `gateway.openfaas.svc.cluster.local:8080`    | OpenFaaS gateway proxied under `/api`        |

Full list: [`deploy/helm/cofrap-frontend/values.yaml`](../../deploy/helm/cofrap-frontend/values.yaml).

## Backend connection

The frontend calls the backend through the **`/api`** prefix, proxied by the pod's nginx to the OpenFaaS gateway — **same origin, no CORS**.

- The proxy target is the chart's **`backend.gateway`** value, injected into the container as the `OPENFAAS_GATEWAY` variable and substituted into `default.conf.template` at startup.
- Default: `gateway.openfaas.svc.cluster.local:8080` — works if OpenFaaS lives in the `openfaas` namespace. Otherwise override it:

  ```bash
  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend \
    --namespace cofrap \
    --set backend.gateway=gateway.my-namespace.svc.cluster.local:8080
  ```

- The OpenFaaS gateway does **not** need to be exposed through an Ingress: the proxy uses the cluster's internal network.
- In **local dev** (`yarn dev`), the Vite dev server proxies `/api` instead — see [`development.md`](development.md).

Flow and API client details: [`architecture.md`](architecture.md#backend-connection).
