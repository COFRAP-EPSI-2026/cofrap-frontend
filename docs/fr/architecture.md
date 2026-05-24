# Architecture

## Vue d'ensemble

Frontend du PoC COFRAP (MSPR TPRE912) : une **SPA** (Single Page Application) qui permet de créer un compte, de s'authentifier et de renouveler ses identifiants en s'appuyant sur les fonctions serverless du backend.

Au runtime, l'application est un ensemble de fichiers statiques (HTML/CSS/JS) servis par **nginx**. Aucun serveur applicatif : tout s'exécute dans le navigateur. Le même nginx **proxifie `/api/*`** vers le gateway OpenFaaS — le navigateur ne parle donc qu'à une seule origine.

```
┌──────────────┐   /          ┌────────────────────────────┐
│  Navigateur  │ ───────────► │  nginx (pod K8s)           │
│  SPA Vue 3   │              │  ├─ /        → SPA /dist   │
│              │   /api/...   │  └─ /api/*   → proxy ───────┼──► Gateway OpenFaaS
└──────────────┘ ───────────► └────────────────────────────┘     (generate-password,
                                                                   generate-2fa,
                                                                   authenticate-user)
```

> **Liaison backend activée** : voir la section [Liaison avec le backend](#liaison-avec-le-backend). Le navigateur appelle `/api/...` en chemin relatif (même origine → aucun CORS).

## Stack technique

| Choix              | Décision                                | Justification                                                          |
|--------------------|------------------------------------------|------------------------------------------------------------------------|
| Framework          | **Vue 3** (Composition API)              | Recommandé pour une SPA légère ; courbe d'apprentissage douce          |
| Build / dev server | **Vite 8**                               | Démarrage instantané, HMR rapide, build optimisé                       |
| Langage            | **TypeScript** (strict, `noUncheckedIndexedAccess`) | Typage statique, vérifié par `vue-tsc`                       |
| Routing            | **vue-router** (history mode)            | Navigation client entre les 4 vues                                     |
| État               | **Pinia**                                | Stores réactifs (`src/stores/`)                                        |
| Client HTTP        | **axios**                                | Client `openfaasApi.ts`, appels au backend via `/api`                  |
| TOTP (génération/vérif client) | **otpauth**                  | Lecture et vérification TOTP côté navigateur                           |
| Décodage QR        | **jsqr**                                 | Décode le PNG QR renvoyé par `generate-password` pour afficher le mot de passe dans l'UI (sans qu'il transite en clair dans la réponse JSON) |
| Icônes             | **lucide-vue-next**                      | `Eye` / `EyeOff` / `Copy` / `Check` pour les toggles password + boutons copier |
| Styles             | **SCSS** (`sass`, BEM)                   | Feuille globale `src/assets/main.scss`                                 |
| Paquets            | **Yarn** classic (lockfile v1)           | `yarn.lock`                                                            |
| Lint / format      | **ESLint** (flat config) + **Prettier** (no-semis, single-quotes, 100c) | Qualité + format vérifiés par la CI (`yarn lint` + `yarn format:check`) |
| Service runtime    | **nginx-unprivileged** (UID 101, port 8080) | Sert le build statique ; pas de runtime Node en production         |

## Structure du dépôt

```
cofrap-frontend/
├── index.html               # Point d'entrée HTML (monté par Vite)
├── vite.config.ts           # Config Vite (alias @ → src/)
├── package.json             # Dépendances + scripts Yarn
├── Dockerfile               # Build multi-stage : node → nginx
├── default.conf.template               # Config nginx (SPA fallback + /healthz)
├── src/
│   ├── main.ts              # Bootstrap : crée l'app Vue, monte router + Pinia
│   ├── App.vue              # Composant racine
│   ├── router/index.ts      # Définition des routes
│   ├── views/               # Une vue par route
│   │   ├── HomeView.vue
│   │   ├── LoginView.vue
│   │   ├── RegisterView.vue
│   │   └── RenewView.vue
│   ├── components/          # Composants réutilisables
│   │   ├── AppHeader.vue
│   │   ├── AuthLayout.vue / AuthCard.vue
│   │   ├── PasswordInput.vue
│   │   ├── A11yPanel.vue    # Panneau d'accessibilité
│   │   └── openfaasApi.ts   # Client API backend (non câblé)
│   ├── composables/         # Logique réutilisable (Composition API)
│   │   ├── useA11y.ts        # Préférences d'accessibilité
│   │   ├── useAudioReading.ts# Lecture audio du contenu
│   │   ├── useLang.ts        # Bascule de langue
│   │   └── useTheme.ts       # Bascule de thème (clair/sombre)
│   ├── lang/                # Traductions
│   │   ├── fr.ts
│   │   └── en.ts
│   └── assets/main.scss     # Styles globaux
└── deploy/helm/cofrap-frontend/   # Chart Helm de déploiement
```

## Routing

`vue-router` en **history mode** (`createWebHistory`). 4 routes :

| Chemin       | Vue              | Rôle                                                                                  |
|--------------|------------------|---------------------------------------------------------------------------------------|
| `/`          | `HomeView`       | Accueil                                                                                |
| `/login`     | `LoginView`      | Authentification d'un utilisateur existant (username + password + TOTP, lock-out local) |
| `/register`  | `RegisterView`   | Création de compte multi-étapes : mot de passe (généré + **affiché via décodage jsqr du QR**) → 2FA (QR + saisie du code) → confirmation |
| `/renew`     | `RenewView`      | Renouvellement des identifiants expirés — mêmes étapes que Register                    |

Le history mode implique que **le serveur doit renvoyer `index.html`** pour toute route inconnue, sinon un rechargement de page sur `/login` donne un 404. C'est le rôle du `try_files ... /index.html` de [`default.conf.template`](../../default.conf.template).

## Affichage du mot de passe (décodage QR côté client)

Le backend `generate-password` ne renvoie le mot de passe en clair **que dans le PNG QR** — jamais dans le champ JSON. Pour offrir une expérience utilisable (affichage masqué/révélé, bouton « Copier »), le frontend **décode lui-même le PNG QR avec [`jsqr`](https://github.com/cozmo/jsQR)** dans les vues `RegisterView` et `RenewView` :

1. Réception du QR PNG (base64) dans la réponse de `generate-password`.
2. Chargement dans un `<canvas>` invisible → `ImageData` → `jsQR(imageData)`.
3. Le payload décodé = le mot de passe en clair → stocké uniquement en `ref()` local (jamais en store/localStorage).
4. Rendu UI : QR cliquable (téléchargement PNG), bouton **Eye/EyeOff** (`lucide-vue-next`) pour révéler le mot de passe, bouton **Copy** (passe à **Check** après succès).

Avantage sécurité : la valeur en clair ne traverse pas l'API en JSON — elle existe dans le bundle d'octets du PNG, qui devient le « canal unique » de transmission tel que défini par le sujet.

## Internationalisation

L'application est bilingue **français / anglais**. Les chaînes sont dans `src/lang/fr.ts` et `src/lang/en.ts`, et la bascule se fait via le composable `useLang`. C'est cohérent avec l'objectif d'environnement inclusif du sujet MSPR.

## Accessibilité

Point fort du projet (sous-tâche « environnement de travail inclusif » du sujet) :

- `A11yPanel.vue` + `useA11y` — panneau de réglages d'accessibilité.
- `useAudioReading` — lecture audio du contenu (utile pour les déficiences visuelles).
- `useTheme` — thème clair/sombre.
- Police **OpenDyslexic** chargée dans `index.html` (confort de lecture pour les profils dyslexiques).

## Liaison avec le backend

Le frontend appelle les 3 fonctions OpenFaaS via le préfixe **`/api`**, en chemin **relatif**. Ce préfixe est proxifié vers le gateway OpenFaaS — deux fois, selon le contexte :

| Contexte        | Qui proxifie `/api` ?                          | Vers                                                  |
|-----------------|------------------------------------------------|-------------------------------------------------------|
| **Production**  | le nginx du pod (`default.conf.template`)      | `${OPENFAAS_GATEWAY}` (défaut `gateway.openfaas.svc.cluster.local:8080`) |
| **Dev local**   | le serveur de dev Vite (`vite.config.ts`)      | `http://127.0.0.1:8080` (gateway port-forwardé)       |

Dans les deux cas le préfixe `/api` est strippé : une requête `/api/function/generate-password` arrive au gateway en `/function/generate-password`.

**Avantages de cette approche :**
- Le navigateur ne voit qu'**une seule origine** (le frontend) → **aucun CORS** à gérer.
- Aucune URL de backend codée en dur dans le bundle : tout est relatif.
- Le gateway OpenFaaS n'a pas besoin d'être exposé publiquement.

**Client API** — `src/components/openfaasApi.ts` : une instance `axios` avec `baseURL: '/api'` et trois fonctions typées : `generatePassword()`, `generate2fa()`, `authenticate()`, plus un helper `apiErrorMessage()`. Les vues importent ce client ; elles ne construisent jamais d'URL elles-mêmes.

L'adresse du gateway en production est configurable via la valeur `backend.gateway` du chart Helm (injectée dans le conteneur comme variable `OPENFAAS_GATEWAY`).

## Build

`yarn build` enchaîne :
1. `vue-tsc --build` — vérification de types TypeScript.
2. `vite build` — bundle de production minifié dans `dist/`.

Le dossier `dist/` (HTML + assets fingerprintés) est ensuite copié dans l'image nginx — voir [`deployment.md`](deployment.md).
