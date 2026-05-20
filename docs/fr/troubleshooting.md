# Troubleshooting

## Développement

### `yarn install` échoue

Vérifier la version de Node : `node --version` doit satisfaire `^20.19 || >=22.12` (champ `engines` de `package.json`). Sinon, installer une version compatible (nvm, fnm, ou l'installeur officiel).

### `yarn build` échoue sur une erreur de types

Le build lance `vue-tsc` (vérification TypeScript) avant le bundling. Lancer `yarn type-check` seul pour isoler l'erreur. Une erreur de type doit être corrigée — elle bloque le build de production.

### Le serveur de dev ne recharge pas (HMR cassé)

Redémarrer `yarn dev`. Si le problème persiste, supprimer le cache Vite : `rm -rf node_modules/.vite`.

## Image Docker

### Le build Docker est très long

Le stage `yarn install` se relance à chaque modification de `package.json`/`yarn.lock`. Tant que ces fichiers ne changent pas, le cache Docker est réutilisé. Ne pas invalider ce cache inutilement (ordre des `COPY` dans le `Dockerfile`).

### `403` ou page blanche au lancement du conteneur

Vérifier que `yarn build` a bien produit `dist/` pendant le build de l'image. Tester : `docker run --rm -p 8080:8080 <image>` puis ouvrir `http://127.0.0.1:8080`.

## Déploiement Kubernetes

### Rechargement de `/login` → 404 nginx

Le SPA fallback n'est pas actif. Vérifier que [`nginx.conf`](../../nginx.conf) contient bien `try_files $uri $uri/ /index.html;` et qu'il est copié dans l'image (`COPY nginx.conf /etc/nginx/conf.d/default.conf`).

### Pod en `ImagePullBackOff`

L'image n'est pas disponible pour le cluster. Soit la builder localement et la charger (voir [`installation.md`](installation.md)), soit publier sur GHCR. Penser à `--set image.pullPolicy=IfNotPresent` pour une image chargée localement.

### Ingress créé mais le site est inaccessible

1. Vérifier que **Traefik** tourne (`kubectl get pods -A | grep traefik`). Sur K3s il est inclus ; sur minikube/autre cluster il faut l'installer via son chart Helm.
2. Vérifier que `ingress.className` (`traefik` par défaut) correspond bien à l'IngressClass exposée par Traefik (`kubectl get ingressclass`).
3. Sans DNS, ajouter le `host` à `/etc/hosts` pointant vers l'IP de l'ingress.
4. minikube : `minikube tunnel` doit tourner pour exposer le LoadBalancer de Traefik.

### Le pod redémarre en boucle (`CrashLoopBackOff`)

Regarder les logs : `kubectl -n cofrap logs -l app.kubernetes.io/name=cofrap-frontend`. nginx-unprivileged écoute sur **8080** — vérifier que le `containerPort`, le `targetPort` du Service et les probes pointent tous vers 8080 / `http`.

### Les probes échouent

Les probes interrogent `/healthz`. Cet endpoint est défini dans `nginx.conf` (`location = /healthz`). S'il a été retiré, les probes échouent — le rétablir ou ajuster `probes.path` dans les values du chart.
