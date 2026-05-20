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
