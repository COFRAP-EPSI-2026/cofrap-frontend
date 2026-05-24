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

Simplest: point at the public GHCR image published by Release Please. Available tags:

| Tag                  | Source                                          | When to use                              |
|----------------------|-------------------------------------------------|------------------------------------------|
| `latest`             | latest stable tag from `main`                   | quick demos (not reproducible)           |
| `2026.X.Y`           | stable tag (Release Please)                     | reproducible deploys (recommended)       |
| `dev`                | latest commit on `dev`                          | testing a feature ahead of a release     |
| `dev-<sha>`          | a specific commit on `dev`                      | traceability                              |

If you work on a fork or before the first push, build locally (the scripts detect the cluster type — minikube, K3s, K3d, KinD):

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

# Linux / WSL / Git Bash
./scripts/prod/build-images.sh                # default tag: "latest"
TAG=mydev ./scripts/prod/build-images.sh      # override the tag

# Windows PowerShell
./scripts/prod/build-images.ps1
./scripts/prod/build-images.ps1 -Tag mydev
```

## Step 2 — Helm deployment

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent \
  --set ingress.host=cofrap.example.com
```

> `image.pullPolicy=IfNotPresent` prevents Kubernetes from trying to re-pull the image from GHCR once it was just loaded locally.

### Exposing through a Cloudflare Tunnel

When the cluster is exposed via a **Cloudflare Tunnel** (public hostname → internal backend), Cloudflare already terminates TLS — no need for the chart's `tls.enabled=true`. Point the tunnel at the **VIP** of the LoadBalancer (e.g. MetalLB) serving the ingress controller:

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=latest \
  --set ingress.host=cofrap.example.com \
  --set ingress.tls.enabled=false
# Cloudflare Zero Trust side: Public hostname → HTTP → <VIP-LB>:80, Path empty.
```

> On a multi-node K3s cluster, the default ServiceLB binds the port on every node — prefer disabling ServiceLB and installing **MetalLB** to get a stable VIP for the tunnel to target (see [`troubleshooting.md`](troubleshooting.md)).

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

### Multi-node K3s + MetalLB (for a stable virtual IP)

K3s' default ServiceLB opens the port on every node, which makes the target address
unstable (several IPs, pod restarts). For a homelab/prod deployment with a Cloudflare
Tunnel or DNS pointing to a **single** IP, disable ServiceLB and install **MetalLB** in
L2 mode:

```bash
# 1. Disable ServiceLB on the K3s server
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<'EOF'
disable:
  - servicelb
EOF
sudo systemctl restart k3s

# 2. Install MetalLB (native manifest — avoid the chart due to an frr-k8s bug)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl -n metallb-system wait --for=condition=Ready pod --all --timeout=120s

# 3. Assign an IP pool (e.g. a single free LAN IP)
kubectl apply -f - <<'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.240/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - lan-pool
EOF
```

The K3s `traefik` service automatically gets the VIP (`kubectl -n kube-system get svc traefik`). That is the IP you then point at from a Cloudflare Tunnel or internal DNS.

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
