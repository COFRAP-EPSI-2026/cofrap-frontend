# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
yarn dev          # Start Vite dev server
yarn build        # Type-check + production build (runs in parallel)
yarn build-only   # Vite build without type-check
yarn type-check   # Run vue-tsc type validation
yarn format       # Prettier formatting on src/
yarn preview      # Preview production build locally
```

No test or lint scripts are configured.

## Architecture

**Vue 3 + Vite PoC** for COFRAP Cloud Identity management — a client-side authentication UI with TOTP 2FA and password management flows.

### Stack
- Vue 3 with Composition API (`<script setup>`) + TypeScript 6
- Vue Router 5 (web history, explicit routes — not file-based)
- SCSS (BEM naming, single global stylesheet at `src/assets/main.scss`)
- Pinia installed but currently unused
- Axios installed but currently unused — backend integration via OpenFaaS is pending (`src/components/openfaasApi.ts` is empty)

### Routes (`src/router/index.ts`)
| Path | View | Purpose |
|------|------|---------|
| `/` | HomeView | Landing |
| `/login` | LoginView | Login + TOTP verification |
| `/register` | RegisterView | Multi-step user registration with QR code |
| `/renew` | RenewView | Credential renewal flow |

### State
No Pinia stores are implemented. State is managed with:
- `localStorage` key `cofrap-user` — username, password, TOTP secret, creation date, expiry status
- `localStorage` key `cofrap-login-security` — login attempt count and lockout timestamp
- Local Vue reactive refs for UI/form state

### TypeScript
- Path alias `@/` → `src/` configured in `tsconfig.app.json` and `vite.config.ts`
- `noUncheckedIndexedAccess: true` — always check array/object accesses for undefined

### Code style
Prettier config (`.prettierrc.json`): no semicolons, single quotes, 100-char line width.
