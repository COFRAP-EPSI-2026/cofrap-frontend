# Architecture

## Overview

Frontend of the COFRAP PoC (MSPR TPRE912): a **SPA** (Single Page Application) that lets users create an account, authenticate and renew their credentials, backed by the serverless backend functions.

At runtime, the app is a set of static files (HTML/CSS/JS) served by **nginx**. No application server: everything runs in the browser.

```
┌─────────────────────────────┐         ┌──────────────────┐
│  Browser                    │  HTTP   │  nginx (K8s pod) │
│  Vue 3 SPA (HTML/CSS/JS)    │ ◄─────► │  /dist files     │
└─────────────────────────────┘         └──────────────────┘
            │
            │  (upcoming — not wired in this version)
            ▼
   OpenFaaS backend (generate-password / generate-2fa / authenticate-user)
```

> The backend connection is **not** enabled in this version. The API client (`src/components/openfaasApi.ts`) exists but is not wired to a real endpoint.

## Tech stack

| Choice             | Decision                         | Rationale                                                              |
|--------------------|----------------------------------|------------------------------------------------------------------------|
| Framework          | **Vue 3** (Composition API)      | Recommended for a lightweight SPA; gentle learning curve               |
| Build / dev server | **Vite**                         | Instant startup, fast HMR, optimised build                             |
| Language           | **TypeScript**                   | Static typing, checked by `vue-tsc`                                    |
| Routing            | **vue-router** (history mode)    | Client-side navigation across the 4 views                              |
| State              | **Pinia**                        | Standard reactive store of the Vue 3 ecosystem                         |
| HTTP client        | **axios**                        | Backend calls (to be wired later)                                      |
| 2FA / QR           | **otplib** / **otpauth** / **qrcode** | Client-side TOTP and QR code generation/reading                  |
| Styles             | **SCSS** (`sass`)                | `src/assets/main.scss` stylesheet                                      |
| Packages           | **Yarn** classic (lockfile v1)   | `yarn.lock`                                                            |
| Runtime service    | **nginx** (non-root image)       | Serves the static build; no Node runtime in production                 |

## Repository layout

```
cofrap-frontend/
├── index.html               # HTML entry point (mounted by Vite)
├── vite.config.ts           # Vite config (alias @ → src/)
├── package.json             # Dependencies + Yarn scripts
├── Dockerfile               # Multi-stage build: node → nginx
├── nginx.conf               # nginx config (SPA fallback + /healthz)
├── src/
│   ├── main.ts              # Bootstrap: creates the Vue app, mounts router + Pinia
│   ├── App.vue              # Root component
│   ├── router/index.ts      # Route definitions
│   ├── views/               # One view per route
│   │   ├── HomeView.vue
│   │   ├── LoginView.vue
│   │   ├── RegisterView.vue
│   │   └── RenewView.vue
│   ├── components/          # Reusable components
│   │   ├── AppHeader.vue
│   │   ├── AuthLayout.vue / AuthCard.vue
│   │   ├── PasswordInput.vue
│   │   ├── A11yPanel.vue    # Accessibility panel
│   │   └── openfaasApi.ts   # Backend API client (not wired)
│   ├── composables/         # Reusable logic (Composition API)
│   │   ├── useA11y.ts        # Accessibility preferences
│   │   ├── useAudioReading.ts# Audio reading of the content
│   │   ├── useLang.ts        # Language switch
│   │   └── useTheme.ts       # Theme switch (light/dark)
│   ├── lang/                # Translations
│   │   ├── fr.ts
│   │   └── en.ts
│   └── assets/main.scss     # Global styles
└── deploy/helm/cofrap-frontend/   # Deployment Helm chart
```

## Routing

`vue-router` in **history mode** (`createWebHistory`). 4 routes:

| Path         | View             | Role                                          |
|--------------|------------------|-----------------------------------------------|
| `/`          | `HomeView`       | Home                                          |
| `/login`     | `LoginView`      | Authentication of an existing user            |
| `/register`  | `RegisterView`   | Account creation (password + 2FA)             |
| `/renew`     | `RenewView`      | Renewal of expired credentials                |

History mode means **the server must return `index.html`** for any unknown route, otherwise reloading the page on `/login` yields a 404. That is the job of the `try_files ... /index.html` in [`nginx.conf`](../../nginx.conf).

## Internationalisation

The app is bilingual **French / English**. Strings live in `src/lang/fr.ts` and `src/lang/en.ts`, and switching is done via the `useLang` composable. This aligns with the inclusive-environment goal of the MSPR brief.

## Accessibility

A strong point of the project (the brief's "inclusive working environment" sub-task):

- `A11yPanel.vue` + `useA11y` — accessibility settings panel.
- `useAudioReading` — audio reading of the content (useful for visual impairments).
- `useTheme` — light/dark theme.
- **OpenDyslexic** font loaded in `index.html` (reading comfort for dyslexic profiles).

## Build

`yarn build` chains:
1. `vue-tsc --build` — TypeScript type checking.
2. `vite build` — minified production bundle in `dist/`.

The `dist/` folder (HTML + fingerprinted assets) is then copied into the nginx image — see [`deployment.md`](deployment.md).
