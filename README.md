<div align="center">

# cofrap-frontend

**🇫🇷 Français** · [🇬🇧 English](README.en.md)

**Frontend du PoC COFRAP** — SPA Vue 3 pour la création de compte, l'authentification et le renouvellement des identifiants (MSPR TPRE912).

[![Vue](https://img.shields.io/badge/Vue-3-4FC08D?logo=vuedotjs&logoColor=white)](https://vuejs.org/)
[![Vite](https://img.shields.io/badge/Vite-8-646CFF?logo=vite&logoColor=white)](https://vite.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![nginx](https://img.shields.io/badge/nginx-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)

</div>

---

## Sommaire

- [Contexte](#contexte)
- [Architecture](#architecture)
- [Vues](#vues)
- [Démarrage rapide](#démarrage-rapide)
- [Déploiement](#déploiement)
- [Structure du dépôt](#structure-du-dépôt)
- [Documentation](#documentation)
- [Contribuer](#contribuer)
- [Licence](#licence)

---

## Contexte

Frontend du PoC **COFRAP** (MSPR TPRE912 — projet de développement serverless). Une **SPA** (Single Page Application) Vue 3 qui doit permettre de créer un compte, de s'authentifier et de renouveler des identifiants expirés, en s'appuyant sur les fonctions serverless du backend.

> Backend OpenFaaS dans un dépôt séparé. Le frontend l'appelle via le préfixe **`/api`**, proxifié (par le nginx du pod en prod, par Vite en dev) vers le gateway OpenFaaS — même origine, aucun CORS.

## Architecture

```
┌─────────────────────────────┐         ┌──────────────────┐
│  Navigateur                 │  HTTP   │  nginx (pod K8s) │
│  SPA Vue 3 (statique)       │ ◄─────► │  /dist           │
└─────────────────────────────┘         └──────────────────┘
```

**Stack** : Vue 3 (Composition API) · Vite · TypeScript · vue-router · Pinia · SCSS — buildée en statique, servie par **nginx**.

Le frontend est **bilingue** (FR/EN) et soigne l'**accessibilité** (panneau dédié, lecture audio, thème clair/sombre, police OpenDyslexic) — en lien avec l'objectif d'environnement inclusif du sujet.

→ Détails : [`docs/fr/architecture.md`](docs/fr/architecture.md).

## Vues

`vue-router` en history mode — 4 routes :

| Chemin       | Vue              | Rôle                                       |
|--------------|------------------|--------------------------------------------|
| `/`          | `HomeView`       | Accueil                                    |
| `/login`     | `LoginView`      | Authentification d'un utilisateur existant |
| `/register`  | `RegisterView`   | Création de compte (mot de passe + 2FA)    |
| `/renew`     | `RenewView`      | Renouvellement des identifiants expirés    |

## Démarrage rapide

> Pré-requis : Node.js `^20.19 || >=22.12`, Yarn classic.

```bash
git clone https://github.com/COFRAP-EPSI-2026/cofrap-frontend.git
cd cofrap-frontend

yarn install      # dépendances
yarn dev          # serveur de dev + HMR → http://localhost:5173
```

Build de production :

```bash
yarn build        # vérification de types + bundle dans dist/
yarn preview      # sert le dist/ buildé en local
```

→ Détails et conventions : [`docs/fr/development.md`](docs/fr/development.md).

## Déploiement

L'application se build dans une **image Docker** (nginx + statique), déployée sur Kubernetes via un **chart Helm**.

```bash
# Image
docker build -t ghcr.io/cofrap-epsi-2026/cofrap-frontend:2026.1.0 .

# Déploiement (chart Deployment + Service + Ingress)
helm install cofrap-frontend ./deploy/helm/cofrap-frontend \
  --namespace cofrap --create-namespace \
  --set ingress.host=cofrap.example.com
```

→ Guide pas-à-pas (K3s / minikube / cluster existant) : [`docs/fr/installation.md`](docs/fr/installation.md).

## Structure du dépôt

```
.
├── README.md / README.en.md         # ce fichier (FR) + version EN
├── index.html                        # point d'entrée HTML
├── package.json                      # dépendances + scripts Yarn
├── vite.config.ts                    # configuration Vite
├── Dockerfile                        # build multi-stage node → nginx
├── default.conf.template                        # config nginx (SPA fallback + /healthz)
├── src/
│   ├── views/                        # 4 vues (home, login, register, renew)
│   ├── components/                   # composants réutilisables
│   ├── composables/                  # logique transverse (a11y, langue, thème)
│   ├── lang/                         # traductions FR / EN
│   ├── router/                       # définition des routes
│   └── assets/                       # styles SCSS
├── deploy/helm/cofrap-frontend/      # chart Helm (Deployment + Service + Ingress)
└── docs/
    ├── fr/                           # documentation française
    └── en/                           # documentation anglaise
```

## Documentation

Documentation bilingue : [`docs/fr/`](docs/fr/README.md) · [`docs/en/`](docs/en/README.md).

| Document                                          | Contenu                                              |
|---------------------------------------------------|------------------------------------------------------|
| [`architecture.md`](docs/fr/architecture.md)      | Stack, structure, routing, i18n, accessibilité       |
| [`development.md`](docs/fr/development.md)         | Setup local, scripts Yarn, conventions               |
| [`deployment.md`](docs/fr/deployment.md)           | Image Docker, chart Helm, options                    |
| [`installation.md`](docs/fr/installation.md)      | Déploiement pas-à-pas K3s / minikube / cluster        |
| [`troubleshooting.md`](docs/fr/troubleshooting.md) | Erreurs fréquentes et résolutions                    |

## Contribuer

1. Fork + branche feature.
2. `yarn install`, puis code avec `yarn dev`.
3. `yarn format` + `yarn type-check` + `yarn build` (tout passe).
4. PR vers `main`.

## Licence

[MIT](https://opensource.org/licenses/MIT) — projet académique MSPR TPRE912 (EPSI / Pro Alterna).

---

<div align="center">
<sub>Réalisé dans le cadre de la MSPR TPRE912 — EPSI / Pro Alterna · Bloc 2.</sub>
</div>
