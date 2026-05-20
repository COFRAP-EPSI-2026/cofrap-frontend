# Déploiement

Le frontend se déploie en deux temps : **construire une image** (nginx + build statique), puis **l'installer** sur Kubernetes via le chart Helm.

> Quickstart cluster (K3s / minikube / cluster existant) : [`installation.md`](installation.md).

## 1. Image Docker

Le [`Dockerfile`](../../Dockerfile) est **multi-stage** :

1. **Stage build** — `node:22-alpine` : `yarn install --frozen-lockfile` puis `yarn build` → `dist/`.
2. **Stage runtime** — `nginxinc/nginx-unprivileged` : copie `dist/` dans `/usr/share/nginx/html` + le template [`default.conf.template`](../../default.conf.template).

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

### Config nginx

[`default.conf.template`](../../default.conf.template) est un **template** : `envsubst` y substitue `${OPENFAAS_GATEWAY}` au démarrage du conteneur (le filtre `NGINX_ENVSUBST_FILTER=^OPENFAAS_` préserve les variables nginx natives). Points clés :

- **Proxy `/api/*`** : proxifie vers `${OPENFAAS_GATEWAY}` (le gateway OpenFaaS). Voir [Liaison avec le backend](#liaison-avec-le-backend).
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
| `backend.gateway`     | `gateway.openfaas.svc.cluster.local:8080`    | Gateway OpenFaaS proxifié sous `/api`        |

Liste complète : [`deploy/helm/cofrap-frontend/values.yaml`](../../deploy/helm/cofrap-frontend/values.yaml).

## Liaison avec le backend

Le frontend appelle le backend via le préfixe **`/api`**, proxifié par le nginx du pod vers le gateway OpenFaaS — **même origine, aucun CORS**.

- La cible du proxy est la valeur **`backend.gateway`** du chart, injectée dans le conteneur comme variable `OPENFAAS_GATEWAY` et substituée dans `default.conf.template` au démarrage.
- Défaut : `gateway.openfaas.svc.cluster.local:8080` — fonctionne si OpenFaaS est dans le namespace `openfaas`. Sinon, surcharger :

  ```bash
  helm upgrade --install cofrap-frontend ./deploy/helm/cofrap-frontend \
    --namespace cofrap \
    --set backend.gateway=gateway.mon-namespace.svc.cluster.local:8080
  ```

- Le gateway OpenFaaS n'a **pas besoin d'être exposé** via un Ingress : le proxy passe par le réseau interne du cluster.
- En **dev local** (`yarn dev`), c'est le serveur Vite qui proxifie `/api` — voir [`development.md`](development.md).

Détails du flux et du client API : [`architecture.md`](architecture.md#liaison-avec-le-backend).
