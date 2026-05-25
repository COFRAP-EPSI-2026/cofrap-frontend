# Architecture

## Overview

Frontend of the COFRAP PoC (MSPR TPRE912): a **SPA** (Single Page Application) that lets users create an account, authenticate and renew their credentials, backed by the serverless backend functions.

At runtime, the app is a set of static files (HTML/CSS/JS) served by **nginx**. No application server: everything runs in the browser. The same nginx also **proxies `/api/*`** to the OpenFaaS gateway — so the browser only ever talks to a single origin.

```
┌──────────────┐   /          ┌────────────────────────────┐
│  Browser     │ ───────────► │  nginx (K8s pod)           │
│  Vue 3 SPA   │              │  ├─ /        → SPA /dist   │
│              │   /api/...   │  └─ /api/*   → proxy ───────┼──► OpenFaaS gateway
└──────────────┘ ───────────► └────────────────────────────┘     (generate-password,
                                                                   generate-2fa,
                                                                   authenticate-user)
```

> **Backend connection enabled**: see [Backend connection](#backend-connection). The browser calls `/api/...` as a relative path (same origin → no CORS).

## Tech stack

| Choice             | Decision                                 | Rationale                                                              |
|--------------------|------------------------------------------|------------------------------------------------------------------------|
| Framework          | **Vue 3** (Composition API)              | Recommended for a lightweight SPA; gentle learning curve               |
| Build / dev server | **Vite 8**                               | Instant startup, fast HMR, optimised build                             |
| Language           | **TypeScript** (strict, `noUncheckedIndexedAccess`) | Static typing, checked by `vue-tsc`                         |
| Routing            | **vue-router** (history mode)            | Client-side navigation across the 4 views                              |
| State              | **Pinia**                                | Reactive stores (`src/stores/`)                                        |
| HTTP client        | **axios**                                | `openfaasApi.ts` client, backend calls via `/api`                      |
| TOTP (client gen/verify) | **otpauth**                        | TOTP reading and verification in the browser                           |
| QR decoding        | **jsqr**                                 | Decodes the PNG QR returned by `generate-password` to display the password in the UI (without sending it in cleartext in the JSON response) |
| Icons              | **lucide-vue-next**                      | `Eye` / `EyeOff` / `Copy` / `Check` for password toggles + copy buttons |
| Styles             | **SCSS** (`sass`, BEM)                   | Global `src/assets/main.scss`                                          |
| Packages           | **Yarn** classic (lockfile v1)           | `yarn.lock`                                                            |
| Lint / format      | **ESLint** (flat config) + **Prettier** (no-semis, single-quotes, 100c) | Quality + formatting checked by CI (`yarn lint` + `yarn format:check`) |
| Runtime service    | **nginx-unprivileged** (UID 101, port 8080) | Serves the static build; no Node runtime in production             |

## Repository layout

```
cofrap-frontend/
├── index.html               # HTML entry point (mounted by Vite)
├── vite.config.ts           # Vite config (alias @ → src/)
├── package.json             # Dependencies + Yarn scripts
├── Dockerfile               # Multi-stage build: node → nginx
├── default.conf.template               # nginx config (SPA fallback + /healthz)
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

| Path         | View             | Role                                                                                  |
|--------------|------------------|---------------------------------------------------------------------------------------|
| `/`          | `HomeView`       | Home                                                                                  |
| `/login`     | `LoginView`      | Authentication of an existing user (username + password + TOTP, local lock-out)       |
| `/register`  | `RegisterView`   | Multi-step account creation: password (generated + **displayed via jsqr QR decoding**) → 2FA (QR + code entry) → confirmation |
| `/renew`     | `RenewView`      | Renewal of expired credentials — same steps as Register                               |

History mode means **the server must return `index.html`** for any unknown route, otherwise reloading the page on `/login` yields a 404. That is the job of the `try_files ... /index.html` in [`default.conf.template`](../../default.conf.template).

## Password display (client-side QR decoding)

The `generate-password` backend only returns the cleartext password **inside the PNG QR** — never in the JSON field. To offer a usable experience (masked/revealed display, "Copy" button), the frontend **decodes the PNG QR itself with [`jsqr`](https://github.com/cozmo/jsQR)** in `RegisterView` and `RenewView`:

1. Receive the PNG QR (base64) from the `generate-password` response.
2. Load it into an invisible `<canvas>` → `ImageData` → `jsQR(imageData)`.
3. The decoded payload = the cleartext password → kept only in a local `ref()` (never in a store / localStorage).
4. UI rendering: clickable QR (PNG download), **Eye/EyeOff** button (`lucide-vue-next`) to reveal the password, **Copy** button (turns into **Check** on success).

Security upside: the cleartext value never travels through the JSON API — it lives inside the PNG byte stream, which becomes the "single channel" of transmission as required by the brief.

## Internationalisation

The app is bilingual **French / English**. Strings live in `src/lang/fr.ts` and `src/lang/en.ts`, and switching is done via the `useLang` composable. This aligns with the inclusive-environment goal of the MSPR brief.

## Accessibility

A strong point of the project (the brief's "inclusive working environment" sub-task):

- `A11yPanel.vue` + `useA11y` — accessibility settings panel.
- `useAudioReading` — audio reading of the content (useful for visual impairments).
- `useTheme` — light/dark theme.
- **OpenDyslexic** font loaded in `index.html` (reading comfort for dyslexic profiles).

## Backend connection

The frontend calls the 3 OpenFaaS functions through the **`/api`** prefix, as a **relative** path. That prefix is proxied to the OpenFaaS gateway — twice, depending on the context:

| Context         | Who proxies `/api`?                            | To                                                    |
|-----------------|------------------------------------------------|-------------------------------------------------------|
| **Production**  | the pod's nginx (`default.conf.template`)      | `${OPENFAAS_GATEWAY}` (default `gateway.openfaas.svc.cluster.local:8080`) |
| **Local dev**   | the Vite dev server (`vite.config.ts`)         | `http://127.0.0.1:8080` (port-forwarded gateway)      |

In both cases the `/api` prefix is stripped: a request `/api/function/generate-password` reaches the gateway as `/function/generate-password`.

**Benefits of this approach:**
- The browser only sees **one origin** (the frontend) → **no CORS** to manage.
- No backend URL hard-coded in the bundle: everything is relative.
- The OpenFaaS gateway does not need to be publicly exposed.

**API client** — `src/components/openfaasApi.ts`: an `axios` instance with `baseURL: '/api'` and three typed functions — `generatePassword()`, `generate2fa()`, `authenticate()` — plus an `apiErrorMessage()` helper. Views import this client; they never build URLs themselves.

The production gateway address is configurable via the Helm chart's `backend.gateway` value (injected into the container as the `OPENFAAS_GATEWAY` variable).

## Build

`yarn build` chains:
1. `vue-tsc --build` — TypeScript type checking.
2. `vite build` — minified production bundle in `dist/`.

The `dist/` folder (HTML + fingerprinted assets) is then copied into the nginx image — see [`deployment.md`](deployment.md).

## Performance & SEO

A few explicit decisions to keep the initial bundle small and SEO clean — enforced by the `lighthouse` CI job.

### Aggressive code splitting

- **Routes** (`router/index.ts`): all use `() => import('@/views/...')` → one chunk per view.
- **`jsqr`** (130 KB of JS): **dynamic import** in `RegisterView`/`RenewView` at decode time (`const jsQR = await import('jsqr')`). Not loaded at view mount — only when the user reaches the password step.
- **`otpauth`**: automatic Vite chunk (statically imported by Register/Renew, ~25 KB).

Result: the home page loads less than 200 KB of JS, and `/register` + `/renew` mount went from ~198 KB to ~78 KB of JS.

### Fonts on demand

- **Montserrat** (Google Fonts): loaded non-blocking via `media="print" onload="this.media='all'"` + `noscript` fallback.
- **OpenDyslexic**: **no longer loaded unconditionally**. The `<link>` is dynamically injected by `useA11y` (`loadOpenDyslexic()`) only when the user enables the "Dyslexia font" option in the accessibility panel. Savings: ~50 KB + 1 DNS + 1 TLS handshake off the critical path for 95% of visitors.

### SEO

- **Dynamic per-route `<title>`**: `useDocumentTitle()` (called in `App.vue`) watches `route.name` + `currentLang` and writes `document.title = t.pageTitles[route.name] + ' — COFRAP Cloud'`. Labels live in `src/lang/{fr,en}.ts` (parity enforced by the `i18n-parity` job).
- **Dynamic `<html lang>`**: updated by `useLang` on every language switch.
- **Open Graph / Twitter Card**: static meta in `index.html` (enough for an internal PoC).
- **`meta name="description"`**: present — resolves the Lighthouse `meta-description` audit.
- **`robots.txt`**: `public/robots.txt` with `Disallow: /` (internal frontend, no public indexing).

### Accessibility — WCAG decisions

Explicit decisions to pass **WCAG 2 AA** on contrast and accessible names, audited by Lighthouse / axe-core:

- **Contrasts** (`main.scss`) — every `--color-*` variable is tuned for ≥ **4.5:1** (normal text) or ≥ **3:1** (large text / UI components). Historical pitfalls fixed:
  - `--color-copy-check` changed from `#22c55e` (vivid green, ~2.4:1 on white) to `#15803d` (~5.2:1)
  - `--color-success-text` (light) changed from `#15803d` to `#14532d` (~7:1 on `--color-success-bg`)
  - `--color-text-faint` (light) changed from `#6b7a94` to `#5a6a82` (~5.5:1 on white)
  - `--color-text-faint` (dark) changed from `#6882a4` to `#8a9fbd` (~5.5:1 on dark)
  - `.steps__circle` (the "done" step) now uses `var(--color-success-text)` instead of the bright `#16a34a`
- **`label-content-name-mismatch`** (axe-core) — any `aria-label` must *include* the button's visible text. Example: the language toggle in `AppHeader` shows the visible text `"FR"` → its aria-label becomes `"Switch language (FR)"`. Otherwise Lighthouse fails.
- **Lucide icons**: always `aria-hidden="true"` when a text label or `aria-label` accompanies the icon (avoids double reading by screen readers).
- **`focus-visible` outline** everywhere (buttons, inputs, links) — overridable by the a11y panel's "Enhanced keyboard focus" option.
- **Audio reading**: `useAudioReading` reads content on focus/hover when enabled. Off by default.
- **OpenDyslexic**: lazy-loaded (see above) — applied to body content, **Montserrat kept on UI chrome** (buttons, header) because OpenDyslexic + `text-transform: uppercase` becomes unreadable.
