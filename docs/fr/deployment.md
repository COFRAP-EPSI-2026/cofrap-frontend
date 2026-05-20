# Déploiement

Le frontend se déploie en deux temps : **construire une image** (nginx + build statique), puis **l'installer** sur Kubernetes via le chart Helm.

> Quickstart cluster (K3s / minikube / cluster existant) : [`installation.md`](installation.md).

## 1. Image Docker

Le [`Dockerfile`](../../Dockerfile) est **multi-stage** :

1. **Stage build** — `node:22-alpine` : `yarn install --frozen-lockfile` puis `yarn build` → `dist/`.
2. **Stage runtime** — `nginxinc/nginx-unprivileged` : copie `dist/` dans `/usr/share/nginx/html` + la config [`nginx.conf`](../../nginx.conf).

L'image finale ne contient **pas** Node : juste nginx + les fichiers statiques. Elle tourne **non-root** (UID 101) et écoute sur le port **8080**.

```bash
# Build
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .

# Test local
docker run --rm -p 8080:8080 ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
# → http://127.0.0.1:8080

# Push (après docker login ghcr.io)
docker push ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0
```

### nginx.conf

Points clés de [`nginx.conf`](../../nginx.conf) :

- **SPA fallback** : `try_files $uri $uri/ /index.html` — indispensable car `vue-router` est en history mode (sans ça, recharger `/login` donne un 404).
- **Cache des assets** : les fichiers `/assets/*` (noms hashés par Vite) sont mis en cache 1 an, `immutable`.
- **`/healthz`** : endpoint de sonde renvoyant `200 ok`, utilisé par le `HEALTHCHECK` Docker et les probes Kubernetes.

## 2. Chart Helm

Le chart [`deploy/helm/cofrap-frontend`](../../deploy/helm/cofrap-frontend) déploie 3 ressources :

| Ressource    | Rôle                                                          |
|--------------|---------------------------------------------------------------|
| `Deployment` | Pod(s) nginx servant la SPA                                   |
| `Service`    | `ClusterIP`, expose le pod en interne (port 80 → 8080)        |
| `Ingress`    | Expose le frontend hors du cluster (désactivable)             |

```bash
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set image.tag=2026.1.0 \
  --set ingress.host=cofrap.example.com \
  --set ingress.className=traefik
```

### Valeurs principales

| Clé                   | Défaut                                       | Description                                  |
|-----------------------|----------------------------------------------|----------------------------------------------|
| `image.repository`    | `ghcr.io/cofrap-epsi-2026/cofrap-frontend`   | Image de la SPA                              |
| `image.tag`           | `2026.1.0`                                   | Tag de l'image                               |
| `replicaCount`        | `1`                                          | Nombre de répliques                          |
| `ingress.enabled`     | `true`                                       | Créer l'Ingress                              |
| `ingress.className`   | `traefik`                                    | IngressClass cible (`""` = classe par défaut) |
| `ingress.host`        | `cofrap.example.com`                         | Nom d'hôte exposé                            |
| `ingress.tls.enabled` | `false`                                      | Activer TLS                                  |

Liste complète : [`deploy/helm/cofrap-frontend/values.yaml`](../../deploy/helm/cofrap-frontend/values.yaml).

## Périmètre de cette version

- Le frontend est déployé **seul** : aucune connexion au backend n'est configurée (pas de proxy `/api`, pas de variable d'environnement backend).
- La mise en relation frontend ↔ backend OpenFaaS sera ajoutée dans une version ultérieure.
