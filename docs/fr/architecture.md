# Architecture

## Vue d'ensemble

Frontend du PoC COFRAP (MSPR TPRE912) : une **SPA** (Single Page Application) qui permet de créer un compte, de s'authentifier et de renouveler ses identifiants en s'appuyant sur les fonctions serverless du backend.

Au runtime, l'application est un ensemble de fichiers statiques (HTML/CSS/JS) servis par **nginx**. Aucun serveur applicatif : tout s'exécute dans le navigateur.

```
┌─────────────────────────────┐         ┌──────────────────┐
│  Navigateur                 │  HTTP   │  nginx (pod K8s) │
│  SPA Vue 3 (HTML/CSS/JS)    │ ◄─────► │  fichiers /dist  │
└─────────────────────────────┘         └──────────────────┘
            │
            │  (à venir — non câblé dans cette version)
            ▼
   Backend OpenFaaS (generate-password / generate-2fa / authenticate-user)
```

> La connexion au backend n'est **pas** activée dans cette version. Le client API (`src/components/openfaasApi.ts`) existe mais n'est pas branché à un endpoint réel.

## Stack technique

| Choix              | Décision                         | Justification                                                          |
|--------------------|----------------------------------|------------------------------------------------------------------------|
| Framework          | **Vue 3** (Composition API)      | Recommandé pour une SPA légère ; courbe d'apprentissage douce          |
| Build / dev server | **Vite**                         | Démarrage instantané, HMR rapide, build optimisé                       |
| Langage            | **TypeScript**                   | Typage statique, vérifié par `vue-tsc`                                 |
| Routing            | **vue-router** (history mode)    | Navigation client entre les 4 vues                                     |
| État               | **Pinia**                        | Store réactif standard de l'écosystème Vue 3                           |
| Client HTTP        | **axios**                        | Appels au backend (à câbler plus tard)                                 |
| 2FA / QR           | **otplib** / **otpauth** / **qrcode** | Génération/lecture TOTP et QR codes côté client                  |
| Styles             | **SCSS** (`sass`)                | Feuille `src/assets/main.scss`                                         |
| Paquets            | **Yarn** classic (lockfile v1)   | `yarn.lock`                                                            |
| Service runtime    | **nginx** (image non-root)       | Sert le build statique ; pas de runtime Node en production             |

## Structure du dépôt

```
cofrap-frontend/
├── index.html               # Point d'entrée HTML (monté par Vite)
├── vite.config.ts           # Config Vite (alias @ → src/)
├── package.json             # Dépendances + scripts Yarn
├── Dockerfile               # Build multi-stage : node → nginx
├── nginx.conf               # Config nginx (SPA fallback + /healthz)
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

| Chemin       | Vue              | Rôle                                          |
|--------------|------------------|-----------------------------------------------|
| `/`          | `HomeView`       | Accueil                                       |
| `/login`     | `LoginView`      | Authentification d'un utilisateur existant    |
| `/register`  | `RegisterView`   | Création de compte (mot de passe + 2FA)       |
| `/renew`     | `RenewView`      | Renouvellement des identifiants expirés       |

Le history mode implique que **le serveur doit renvoyer `index.html`** pour toute route inconnue, sinon un rechargement de page sur `/login` donne un 404. C'est le rôle du `try_files ... /index.html` de [`nginx.conf`](../../nginx.conf).

## Internationalisation

L'application est bilingue **français / anglais**. Les chaînes sont dans `src/lang/fr.ts` et `src/lang/en.ts`, et la bascule se fait via le composable `useLang`. C'est cohérent avec l'objectif d'environnement inclusif du sujet MSPR.

## Accessibilité

Point fort du projet (sous-tâche « environnement de travail inclusif » du sujet) :

- `A11yPanel.vue` + `useA11y` — panneau de réglages d'accessibilité.
- `useAudioReading` — lecture audio du contenu (utile pour les déficiences visuelles).
- `useTheme` — thème clair/sombre.
- Police **OpenDyslexic** chargée dans `index.html` (confort de lecture pour les profils dyslexiques).

## Build

`yarn build` enchaîne :
1. `vue-tsc --build` — vérification de types TypeScript.
2. `vite build` — bundle de production minifié dans `dist/`.

Le dossier `dist/` (HTML + assets fingerprintés) est ensuite copié dans l'image nginx — voir [`deployment.md`](deployment.md).
