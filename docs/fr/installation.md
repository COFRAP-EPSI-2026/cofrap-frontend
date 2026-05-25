# Installation pas-à-pas

Déployer le frontend COFRAP sur **K3s**, **minikube** ou un **cluster existant**, sous **Linux** ou **Windows**.

## Sommaire

- [Pré-requis](#pré-requis)
- [Étape 1 — image Docker](#étape-1--image-docker)
- [Étape 2 — déploiement Helm](#étape-2--déploiement-helm)
- [Variante minikube](#variante-minikube)
- [Variante K3s](#variante-k3s)
- [Vérification](#vérification)
- [Désinstallation](#désinstallation)

## Pré-requis

| Outil      | Rôle                                              |
|------------|---------------------------------------------------|
| `docker`   | Construire l'image                                |
| `kubectl`  | Piloter le cluster                                |
| `helm` ≥ 3 | Déployer le chart                                 |
| Un cluster | K3s, minikube ou managé, avec un ingress controller |

## Étape 1 — image Docker

Le plus simple : pointer sur l'image GHCR publique publiée par Release Please. Les tags disponibles :

| Tag                  | Provenance                                      | Quand l'utiliser                        |
|----------------------|-------------------------------------------------|------------------------------------------|
| `latest`             | dernier tag stable de `main`                    | démos rapides (pas reproductible)       |
| `2026.X.Y`           | tag stable (Release Please)                     | déploiement reproductible (recommandé)  |
| `dev`                | dernier commit `dev`                            | test d'une feature avant release        |
| `dev-<sha>`          | commit précis sur `dev`                         | traçabilité                              |

Si tu travailles sur un fork ou avant le premier push, builder localement (les scripts détectent le type de cluster — minikube, K3s, K3d, KinD) :

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

# Linux / WSL / Git Bash
./scripts/prod/build-images.sh                # tag par défaut : "latest"
TAG=mydev ./scripts/prod/build-images.sh      # surcharger le tag

# Windows PowerShell
./scripts/prod/build-images.ps1
./scripts/prod/build-images.ps1 -Tag mydev
```

## Étape 2 — déploiement Helm

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent \
  --set ingress.host=cofrap.example.com
```

> `image.pullPolicy=IfNotPresent` évite que Kubernetes tente de re-télécharger l'image depuis GHCR lorsqu'elle vient d'être chargée localement.

### Exposition derrière un Cloudflare Tunnel

Si le cluster est exposé via un **Cloudflare Tunnel** (hostname public → backend interne), Cloudflare termine déjà TLS — pas besoin de l'Ingress chart `tls.enabled=true`. Pointer le tunnel sur le **VIP** du LoadBalancer (ex. MetalLB) qui sert le contrôleur d'Ingress :

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=latest \
  --set ingress.host=cofrap.example.com \
  --set ingress.tls.enabled=false
# Côté Cloudflare Zero Trust : Public hostname → HTTP → <VIP-LB>:80, Path vide.
```

> Pour un cluster K3s multi-node, ServiceLB par défaut bind sur chaque node — préférer désactiver ServiceLB et installer **MetalLB** pour avoir un VIP stable que le tunnel cible (cf. [`troubleshooting.md`](troubleshooting.md)).

## Variante minikube

minikube n'a pas d'addon Traefik — on l'installe via son chart Helm :

```bash
minikube start --cpus=2 --memory=4096

# Installer Traefik comme ingress controller
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --namespace traefik --create-namespace

# … étape 1 puis étape 2 (ingress.className=traefik est le défaut du chart)
minikube tunnel                       # exposer l'ingress (laisser tourner)
```

## Variante K3s

K3s embarque **Traefik** comme ingress controller — rien à installer, `ingress.className=traefik` (le défaut du chart) fonctionne directement.

```bash
curl -sfL https://get.k3s.io | sh -
# … étape 1 puis étape 2 avec --set ingress.className=traefik
```

### K3s multi-node + MetalLB (pour exposer une IP virtuelle stable)

ServiceLB par défaut de K3s ouvre le port sur chaque node, ce qui rend l'adresse cible instable
(plusieurs IPs, redémarrage de pods). Pour un déploiement homelab/prod avec Cloudflare Tunnel
ou un DNS pointant vers une **seule** IP, désactiver ServiceLB et installer **MetalLB** en
mode L2 :

```bash
# 1. Désactiver ServiceLB côté serveur K3s
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<'EOF'
disable:
  - servicelb
EOF
sudo systemctl restart k3s

# 2. Installer MetalLB (manifeste natif — éviter le chart à cause d'un bug frr-k8s)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl -n metallb-system wait --for=condition=Ready pod --all --timeout=120s

# 3. Attribuer un pool d'IPs (ex. une seule IP du LAN libre)
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

Le service `traefik` de K3s prend automatiquement le VIP (`kubectl -n kube-system get svc traefik`). C'est cette IP que tu pointes ensuite depuis Cloudflare Tunnel ou un DNS interne.

## Vérification

```bash
kubectl -n cofrap get deploy,svc,ingress,pods -l app.kubernetes.io/name=cofrap-frontend
```

État attendu : un pod `Running 1/1`, un Service `ClusterIP`, un Ingress avec une adresse.

Accès :

```bash
# Via l'Ingress (ajouter le host à /etc/hosts s'il n'y a pas de DNS)
curl -H 'Host: cofrap.example.com' http://<ip-ingress>/healthz

# Ou sans Ingress, en port-forward
kubectl -n cofrap port-forward svc/cofrap-frontend 8080:80
# → http://127.0.0.1:8080
```

## Désinstallation

```bash
helm uninstall cofrap-frontend -n cofrap
```

## Troubleshooting

Voir [`troubleshooting.md`](troubleshooting.md).
