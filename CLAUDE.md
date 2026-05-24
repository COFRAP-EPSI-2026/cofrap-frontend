# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Vue d'ensemble

Frontend Vue 3 du PoC **COFRAP** (MSPR TPRE912). SPA statique buildée par Vite, servie par nginx en prod. Backend serverless OpenFaaS dans un dépôt séparé (`cofrap-backend`), appelé via le préfixe relatif `/api/*` proxifié vers le gateway — **aucun CORS** à gérer côté navigateur.

Le `README.md` (FR) et `README.en.md` (EN) racine sont la porte d'entrée utilisateur. La documentation détaillée est **bilingue** : `docs/fr/` et `docs/en/` (contenu en miroir). Cette page ne répète pas le README — elle pointe vers ce que Claude doit savoir pour bouger vite.

## Stack et architecture

- **Vue 3** (Composition API, `<script setup>`) + **TypeScript 6** strict (`noUncheckedIndexedAccess: true`).
- **Vite 8** (dev server + build) ; alias `@/` → `src/` configuré dans `vite.config.ts` + `tsconfig.app.json`.
- **vue-router** 5 (history mode, routes explicites — pas de file-based routing).
- **Pinia** pour les stores (`src/stores/`).
- **Axios** pour les appels HTTP — client centralisé `src/components/openfaasApi.ts` (`baseURL: '/api'`, fonctions typées `generatePassword()` / `generate2fa()` / `authenticate()` + helper `apiErrorMessage()`).
- **SCSS** (BEM, feuille globale unique `src/assets/main.scss`).
- **otpauth** : lecture/validation TOTP côté client.
- **jsqr** : décodage des QR PNG renvoyés par `generate-password` pour afficher/copier le mot de passe dans l'UI (Register + Renew, étape « mot de passe »).
- **lucide-vue-next** : icônes (`Eye`, `EyeOff`, `Copy`, `Check`, etc.).
- **i18n maison** : `src/lang/fr.ts` / `en.ts` + composable `useLang`. Toutes les chaînes affichées doivent y vivre.
- **Accessibilité** : `A11yPanel.vue` + composables `useA11y`, `useAudioReading`, `useTheme` ; police **OpenDyslexic**.
- **nginx-unprivileged** (UID 101, port 8080) en runtime — image multi-stage `node:22-alpine` → `nginxinc/nginx-unprivileged`.

Architecture complète : [`docs/fr/architecture.md`](docs/fr/architecture.md).

## Structure du dépôt (résumé)

```
src/
  main.ts                 # bootstrap (Pinia + router)
  App.vue
  router/index.ts         # 4 routes : /, /login, /register, /renew
  views/                  # une vue par route
  components/
    AppHeader.vue, AuthLayout.vue, AuthCard.vue,
    PasswordInput.vue, A11yPanel.vue,
    openfaasApi.ts        # client axios — single source of API truth
  composables/            # useA11y, useAudioReading, useLang, useTheme
  stores/                 # Pinia
  lang/{fr,en}.ts         # i18n
  assets/main.scss        # styles globaux (BEM)
deploy/
  helm/cofrap-frontend/   # chart Helm (Deployment + Service + Ingress)
docs/
  fr/ , en/               # doc bilingue EN MIROIR (architecture, development, deployment, installation, troubleshooting)
scripts/
  prod/                   # déploiement cluster (install / uninstall / build-images en .sh + .ps1)
  dev/                    # dev local (yarn dev wrappers)
.github/workflows/        # ci.yml + pre-release.yml + release-please.yml
Dockerfile                # multi-stage node → nginx (non-root)
default.conf.template     # config nginx (envsubst OPENFAAS_GATEWAY au boot)
vite.config.ts            # proxy /api → http://127.0.0.1:8080 en dev
```

## Commandes courantes

```bash
yarn install            # dépendances
yarn dev                # serveur Vite + HMR → http://localhost:5173
yarn build              # type-check (vue-tsc) + bundle dist/
yarn build-only         # build sans type-check
yarn type-check         # vue-tsc --build
yarn lint               # ESLint (.ts + .vue) — yarn lint --fix pour auto-fixer
yarn format             # Prettier sur src/
yarn format:check       # Prettier en mode vérification (CI)
yarn preview            # sert dist/ en local
```

Reproduire la validation CI en local : `yarn lint && yarn format:check && yarn type-check && yarn build`.

### Backend en local (deux options)

Le proxy Vite de `/api` cible `http://127.0.0.1:8080` (cf. `vite.config.ts`).

```bash
# Option A : stack docker-compose du backend (recommandé — pas de cluster requis)
cd ../cofrap-backend && docker compose up -d --build

# Option B : gateway d'un cluster OpenFaaS
kubectl -n openfaas port-forward svc/gateway 8080:8080
```

## Liaison avec le backend (mécanisme à respecter)

- **Toujours** utiliser `src/components/openfaasApi.ts`. Pas de `fetch()`/`axios` direct dans une vue ; le client expose `generatePassword`, `generate2fa`, `authenticate`, `apiErrorMessage`. Si tu ajoutes un endpoint, étends ce client.
- URL **relatives** uniquement : `/api/...`. Le préfixe est strippé par nginx (prod) ou par le proxy Vite (dev). Aucune URL absolue d'environnement ne doit fuiter dans le bundle.
- Pas de CORS à gérer côté frontend — c'est le proxy même-origine qui le résout. Les vues ne doivent pas inventer d'en-têtes CORS.
- En **production**, l'adresse réelle du gateway est dans `backend.gateway` du chart Helm (injectée comme variable `OPENFAAS_GATEWAY` dans le conteneur, substituée dans `default.conf.template`).

## Conventions critiques pour Claude

- **Documentation bilingue en miroir — RÈGLE PERMANENTE** : `docs/fr/` et `docs/en/` ont une structure identique. **Toute** modification de doc se fait dans les **deux** langues dans le même changement. Idem pour `README.md` (FR) et `README.en.md` (EN). Si tu touches un contenu documentaire et que tu ne mets à jour qu'une langue, le travail est incomplet.
- **i18n d'abord** : aucune chaîne affichée ne doit être codée en dur dans un composant. Toujours passer par `src/lang/fr.ts` + `src/lang/en.ts` (les deux clés). Sinon : régression silencieuse côté EN.
- **Accessibilité non négociable** : `useA11y` (préférences), `useTheme` (clair/sombre), OpenDyslexic, `useAudioReading`. Vérifier que les nouveaux composants respectent ces préférences (focus visible, contraste, ARIA labels).
- **TypeScript strict** : `noUncheckedIndexedAccess` est activé — toute lecture `arr[i]` / `obj[key]` retourne `T | undefined`, à valider. Pas de `as any` pour contourner.
- **Prettier** : pas de point-virgules, single quotes, largeur 100. Lancer `yarn format` avant chaque commit (ou compter sur la CI `format:check` qui *bloque*).
- **ESLint** : règles Vue + TypeScript dans `eslint.config.js` (flat config). Les imports non utilisés sont une erreur — c'est ce qui a remonté que `useAudioReading` avait été importé sans être consommé.
- **Pas de fichiers Vue sans `<script setup lang="ts">`** : la base du projet ne supporte que Composition API + TS.
- **Style** : BEM dans `main.scss` (une seule feuille globale). Pas de `<style scoped>` dispersé sauf cas particulier — la cohérence visuelle passe par cette feuille.

## Vues et flux

| Route        | Vue              | Rôle                                                         |
|--------------|------------------|--------------------------------------------------------------|
| `/`          | `HomeView`       | Landing                                                      |
| `/login`     | `LoginView`      | Auth username + password + TOTP, gère lock-out local         |
| `/register`  | `RegisterView`   | Multi-étapes : générer mot de passe → afficher (QR + reveal + copy) → activer 2FA → confirmer code TOTP |
| `/renew`     | `RenewView`      | Même flux que Register mais sur un compte existant `expired` |

L'étape « mot de passe » de Register/Renew utilise `jsqr` pour **décoder le PNG QR** renvoyé par `generate-password` et afficher le mot de passe en clair (toggle Eye/EyeOff, bouton Copy avec confirmation Check). Le scan navigateur évite que le mot de passe passe en clair dans la réponse JSON — la fonction backend ne le retourne que dans le QR.

## État

- **Pinia** pour les stores partagés (`src/stores/`).
- `localStorage` pour la persistance utile entre sessions : `cofrap-user` (username, état de session côté UI) et `cofrap-login-security` (compteur d'échecs + horodatage de lock-out local). **Ne jamais** y mettre de mot de passe ou de secret TOTP.

## CI/CD

Trois workflows GitHub Actions :

| Workflow                                                     | Déclencheur                  | Rôle                                                                                                |
|--------------------------------------------------------------|------------------------------|-----------------------------------------------------------------------------------------------------|
| [`ci.yml`](.github/workflows/ci.yml)                         | PR vers `dev` ou `main`      | **Validation** : `lint` → `format:check` → `type-check` → `build` → build de l'image (sans push). Réutilisable via `workflow_call`. |
| [`pre-release.yml`](.github/workflows/pre-release.yml)       | push sur `dev` (+ merge-group)| Rejoue `ci.yml`, puis **publie l'image `:dev`** (+ `:dev-<sha>`) sur GHCR (multi-arch `linux/amd64,linux/arm64`). |
| [`release-please.yml`](.github/workflows/release-please.yml) | push sur `main`              | **Voie principale de release** : Release PR → merge → tag `vX.Y.Z` + image `2026.X.Y` + `latest`. |

Toutes les publications GHCR utilisent `provenance: false` (évite les entrées d'arch `unknown/unknown`). Le PAT GHCR vit dans le secret `GHCR_PAT_TOKEN` (pas `GITHUB_TOKEN` : préfixe `GITHUB_` interdit en custom secret par GitHub, et le token par défaut est bloqué par certaines policies d'org).

## Versioning

Versioning **calendaire** `YYYY.MINOR.PATCH`. Les releases sont **automatisées par Release Please** — **ne JAMAIS bumper la version à la main**.

Fichiers porteurs de version (annotés `# x-release-please-version` / `<!-- x-release-please-version -->`, bumpés automatiquement) :
- `package.json` (auto-bump natif Release Please pour `node`)
- `deploy/helm/cofrap-frontend/Chart.yaml` (×2 : `version` + `appVersion`)
- `deploy/helm/cofrap-frontend/values.yaml` (`image.tag`)
- `README.md` + `README.en.md` (ligne « version courante »)

**Si tu ajoutes un nouveau fichier portant la version** : pose l'annotation `# x-release-please-version` (ou `<!-- x-release-please-version -->` en markdown) sur la ligne, et ajoute le chemin dans `extra-files` de `release-please-config.json`.

Prérequis (une seule fois) : `Settings → Actions → General → Workflow permissions` → cocher « Allow GitHub Actions to create and approve pull requests ».

## Quand tu finis quelque chose

1. `yarn lint --fix && yarn format` (sinon la CI `format:check` te bloquera).
2. `yarn type-check` (zéro erreur).
3. `yarn build` doit passer (le type-check + le bundle).
4. Toutes les nouvelles chaînes UI doivent vivre dans `src/lang/fr.ts` **et** `src/lang/en.ts`.
5. Si tu touches un comportement utilisateur, mettre à jour `docs/fr/` **et** `docs/en/` (`development.md`, `architecture.md`, ou `troubleshooting.md` selon le cas) — dans le **même changement**.
6. **Ne pas bumper la version manuellement** : Release Please s'en charge. Utiliser des commits Conventional (`feat:`, `fix:`, `chore:`, `docs:`).
7. Pas de README/docs autogénérés sans demande explicite — le PoC veut rester lisible et concis.
