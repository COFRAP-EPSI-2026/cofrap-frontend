# Chart Helm `cofrap-frontend`

Déploie le frontend Vue 3 du PoC COFRAP — une SPA statique servie par nginx — sur un cluster Kubernetes.

Procédure complète (FR/EN) : [`docs/fr/installation.md`](../../../docs/fr/installation.md) · [`docs/en/installation.md`](../../../docs/en/installation.md).

## Contenu déployé

| Ressource     | Rôle                                                             |
|---------------|------------------------------------------------------------------|
| `Deployment`  | Pod(s) nginx servant le build Vite statique (non-root, UID 101)  |
| `Service`     | `ClusterIP`, expose le pod en interne (port 80 → conteneur 8080) |
| `Ingress`     | Expose le frontend hors du cluster (désactivable)                |

## Pré-requis

1. Un cluster Kubernetes (K3s, minikube, K8s managé…).
2. `helm` ≥ 3.x et `kubectl` configurés.
3. **Traefik** comme ingress controller si `ingress.enabled=true` (inclus nativement dans K3s ; sur minikube/autre cluster, l'installer via son chart Helm).
4. L'image `ghcr.io/cofrap-epsi-2026/cofrap-frontend` disponible — ou buildée localement (voir doc).

## Installation

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set ingress.host=cofrap.example.com
```

> L'Ingress cible par défaut l'IngressClass **`traefik`**. Sur un cluster sans Traefik, l'installer ou surcharger `--set ingress.className=<ta-classe>`.

Validation sans appliquer :

```bash
helm lint deploy/helm/cofrap-frontend
helm template cofrap-frontend deploy/helm/cofrap-frontend
```

## Valeurs surchargeables

Voir [`values.yaml`](values.yaml) — commenté. Les plus utiles :

| Clé                     | Défaut                                       | Description                                          |
|-------------------------|----------------------------------------------|------------------------------------------------------|
| `image.repository`      | `ghcr.io/cofrap-epsi-2026/cofrap-frontend`   | Image de la SPA                                      |
| `image.tag`             | `2026.1.0`                                   | Tag de l'image                                       |
| `replicaCount`          | `1`                                          | Nombre de répliques                                  |
| `ingress.enabled`       | `true`                                       | Créer l'Ingress                                      |
| `ingress.className`     | `traefik`                                    | IngressClass cible (`""` = classe par défaut)        |
| `ingress.host`          | `cofrap.example.com`                         | Nom d'hôte exposé                                    |
| `ingress.tls.enabled`   | `false`                                      | Activer TLS (nécessite `tls.secretName`)             |

## Désinstallation

```bash
helm uninstall cofrap-frontend -n cofrap
```

## Liaison backend

Le nginx du pod proxifie `/api/*` vers le gateway OpenFaaS — le navigateur reste sur une seule origine (aucun CORS). La cible est la valeur **`backend.gateway`** (défaut `gateway.openfaas.svc.cluster.local:8080`), injectée dans le conteneur comme variable `OPENFAAS_GATEWAY` :

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend -n cofrap \
  --set backend.gateway=gateway.openfaas.svc.cluster.local:8080
```

Le gateway OpenFaaS n'a **pas** besoin d'être exposé par un Ingress — le proxy passe par le réseau interne du cluster.

## Notes

- Le pod tourne **non-root** (image `nginxinc/nginx-unprivileged`, UID 101, port 8080).
