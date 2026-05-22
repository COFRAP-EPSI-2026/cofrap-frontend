# Développement local

## Pré-requis

- **Node.js** `^20.19` ou `>= 22.12` (voir `engines` dans `package.json`)
- **Yarn** classic (1.x)
- Un navigateur moderne

## Setup initial

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

# Installer les dépendances
yarn install
```

## Lancer en développement

```bash
yarn dev
```

Vite démarre un serveur de dev avec **HMR** (hot module replacement) — par défaut sur `http://localhost:5173`. Toute modification d'un `.vue` / `.ts` est répercutée instantanément.

## Scripts Yarn

| Script             | Effet                                                                  |
|--------------------|------------------------------------------------------------------------|
| `yarn dev`         | Serveur de dev Vite + HMR                                              |
| `yarn build`       | Vérification de types (`vue-tsc`) **puis** build de production (`dist/`) |
| `yarn build-only`  | Build de production sans vérification de types                         |
| `yarn type-check`  | Vérification TypeScript seule (`vue-tsc --build`)                      |
| `yarn lint`        | Analyse ESLint des `.ts` / `.vue` (`yarn lint --fix` pour corriger)     |
| `yarn preview`     | Sert localement le `dist/` déjà buildé (vérifier le rendu prod)         |
| `yarn format`      | Formate `src/` avec Prettier                                           |
| `yarn format:check`| Vérifie le formatage sans modifier les fichiers (utilisé par la CI)     |

## Conventions de code

- **TypeScript** partout — les `.vue` utilisent `<script setup lang="ts">`.
- **Composition API** Vue 3 ; la logique transverse vit dans `src/composables/`.
- **ESLint** (`eslint.config.js` — règles Vue + TypeScript) pour la qualité du code. Lancer `yarn lint`.
- **Prettier** pour le formatage (`.prettierrc.json`). Lancer `yarn format` avant de commit.
- Alias d'import **`@`** → `src/` (configuré dans `vite.config.ts` et `tsconfig`). Ex. `import HomeView from '@/views/HomeView.vue'`.
- Les chaînes affichées passent par les fichiers de langue `src/lang/{fr,en}.ts` — ne pas coder de texte en dur dans les composants.

## Cycle de dev typique

1. `yarn dev` et coder.
2. `yarn lint` + `yarn format` — qualité du code et formatage.
3. `yarn type-check` — pas d'erreur de types.
4. `yarn build` — le build de production passe.
5. Commit + PR.

## Vérifier le rendu de production en local

```bash
yarn build
yarn preview
```

`yarn preview` sert le `dist/` sur un port local — c'est le contenu exact qui sera servi par nginx en production.

## Travailler avec le backend en local

Le frontend appelle le backend via `/api` (chemin relatif). En dev, Vite proxifie
`/api` vers `http://127.0.0.1:8080` (cf. `server.proxy` dans `vite.config.ts`). Il
suffit donc d'avoir le backend joignable sur le port 8080 — deux façons :

### Option A — stack `docker compose` du backend (recommandé, sans cluster)

Le dépôt backend fournit un `docker-compose.yml` qui démarre MariaDB, les 3
fonctions et un Traefik exposant le gateway sur `http://localhost:8080` :

```bash
# dans le dépôt cofrap-backend
docker compose up -d --build
```

Puis, côté frontend : `yarn dev`. Les appels `/api/function/<name>` traversent le
proxy Vite → Traefik → fonction. Aucun cluster requis, aucun CORS (même origine
`localhost:5173`).

### Option B — gateway d'un cluster OpenFaaS

Si le backend tourne déjà sur un cluster, exposer son gateway sur le port 8080 :

```bash
kubectl -n openfaas port-forward svc/gateway 8080:8080
```

Si rien n'écoute sur le port 8080, l'app se charge mais les appels API échouent — c'est attendu.

## Tester l'image Docker en local

```bash
docker build -t cofrap-frontend:dev .
docker run --rm -p 8080:8080 cofrap-frontend:dev
# → http://127.0.0.1:8080
```

> Sans cluster derrière, le proxy `/api` du conteneur ne joindra pas de gateway — seule la SPA est testable ainsi.

→ Détails image + déploiement : [`deployment.md`](deployment.md).

## Intégration continue et pré-releases

Trois workflows GitHub Actions, faciles à suivre :

| Workflow | Déclencheur | Rôle |
|----------|-------------|------|
| `ci.yml` | PR vers `dev` ou `main` | **Validation** : `lint` → `format:check` → `type-check` → `build` → build image (sans push) |
| `pre-release.yml` | push sur `dev` | Rejoue `ci.yml` ; si vert, **publie l'image `:dev`** (+ `:dev-<sha>`) sur GHCR |
| `release-please.yml` | push sur `main` | **Release stable** (voir ci-dessous) |

Reproduire la validation en local : `yarn lint && yarn format:check && yarn type-check && yarn build`.

## Releases (Release Please)

Le versionnement est **calendaire** (`YYYY.MINOR.PATCH`) et **automatisé** par
[Release Please](https://github.com/googleapis/release-please), comme sur le backend :

- Pousser des commits [Conventional](https://www.conventionalcommits.org/)
  (`feat:` → bump mineur, `fix:` → bump correctif) sur `main`.
- Release Please maintient une « Release PR » qui bumpe `package.json`,
  `Chart.yaml`, `values.yaml` et le `CHANGELOG.md`.
- Merger cette PR crée le tag `vX.Y.Z` + la GitHub Release, puis
  `.github/workflows/release-please.yml` build et pousse l'image sur GHCR.

Ne **jamais** bumper la version à la main. Fichiers porteurs de version :
`package.json` (auto), `deploy/helm/cofrap-frontend/Chart.yaml` (×2) et
`deploy/helm/cofrap-frontend/values.yaml` (annotés `# x-release-please-version`).

Prérequis (une seule fois) : Settings → Actions → General → Workflow permissions
→ cocher « Allow GitHub Actions to create and approve pull requests ».

## Problèmes courants

Voir [`troubleshooting.md`](troubleshooting.md).
