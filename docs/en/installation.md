# Step-by-step installation

Deploy the COFRAP frontend on **K3s**, **minikube** or an **existing cluster**, on **Linux** or **Windows**.

## Table of contents

- [Prerequisites](#prerequisites)
- [Step 1 — Docker image](#step-1--docker-image)
- [Step 2 — Helm deployment](#step-2--helm-deployment)
- [minikube variant](#minikube-variant)
- [K3s variant](#k3s-variant)
- [Verification](#verification)
- [Uninstall](#uninstall)

## Prerequisites

| Tool       | Role                                              |
|------------|---------------------------------------------------|
| `docker`   | Build the image                                   |
| `kubectl`  | Drive the cluster                                 |
| `helm` ≥ 3 | Deploy the chart                                  |
| A cluster  | K3s, minikube or managed, with an ingress controller |

## Step 1 — Docker image

As long as no release is published to GHCR, build the image locally and make it available to the cluster.

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .
```

Load the image into the cluster depending on its type:

```bash
# minikube
minikube image load ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0

# K3s
docker save ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 | sudo k3s ctr images import -

# KinD
kind load docker-image ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
```

## Step 2 — Helm deployment

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=2026.1.0 \
  --set image.pullPolicy=IfNotPresent \
  --set ingress.host=cofrap.example.com
```

> `image.pullPolicy=IfNotPresent` prevents Kubernetes from trying to re-pull the image from GHCR (where it doesn't exist until a release is published).

## minikube variant

minikube has no Traefik addon — install it via its Helm chart:

```bash
minikube start --cpus=2 --memory=4096

# Install Traefik as the ingress controller
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --namespace traefik --create-namespace

# … step 1 then step 2 (ingress.className=traefik is the chart default)
minikube tunnel                       # expose the ingress (leave running)
```

## K3s variant

K3s ships **Traefik** as the ingress controller — nothing to install, `ingress.className=traefik` (the chart default) works out of the box.

```bash
curl -sfL https://get.k3s.io | sh -
# … step 1 then step 2 with --set ingress.className=traefik
```

## Verification

```bash
kubectl -n cofrap get deploy,svc,ingress,pods -l app.kubernetes.io/name=cofrap-frontend
```

Expected state: one `Running 1/1` pod, a `ClusterIP` Service, an Ingress with an address.

Access:

```bash
# Via the Ingress (add the host to /etc/hosts if there is no DNS)
curl -H 'Host: cofrap.example.com' http://<ingress-ip>/healthz

# Or without an Ingress, via port-forward
kubectl -n cofrap port-forward svc/cofrap-frontend 8080:80
# → http://127.0.0.1:8080
```

## Uninstall

```bash
helm uninstall cofrap-frontend -n cofrap
```

## Troubleshooting

See [`troubleshooting.md`](troubleshooting.md).
