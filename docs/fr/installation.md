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

Tant qu'aucune release n'est publiée sur GHCR, builder l'image localement et la rendre disponible au cluster.

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .
```

Charger l'image dans le cluster selon le type :

```bash
# minikube
minikube image load ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0

# K3s
docker save ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 | sudo k3s ctr images import -

# KinD
kind load docker-image ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
```

## Étape 2 — déploiement Helm

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=2026.1.0 \
  --set image.pullPolicy=IfNotPresent \
  --set ingress.host=cofrap.example.com
```

> `image.pullPolicy=IfNotPresent` évite que Kubernetes tente de re-télécharger l'image depuis GHCR (où elle n'existe pas tant qu'aucune release n'est publiée).

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
