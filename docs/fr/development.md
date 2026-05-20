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
| `yarn preview`     | Sert localement le `dist/` déjà buildé (vérifier le rendu prod)         |
| `yarn format`      | Formate `src/` avec Prettier                                           |

## Conventions de code

- **TypeScript** partout — les `.vue` utilisent `<script setup lang="ts">`.
- **Composition API** Vue 3 ; la logique transverse vit dans `src/composables/`.
- **Prettier** pour le formatage (`.prettierrc.json`). Lancer `yarn format` avant de commit.
- Alias d'import **`@`** → `src/` (configuré dans `vite.config.ts` et `tsconfig`). Ex. `import HomeView from '@/views/HomeView.vue'`.
- Les chaînes affichées passent par les fichiers de langue `src/lang/{fr,en}.ts` — ne pas coder de texte en dur dans les composants.

## Cycle de dev typique

1. `yarn dev` et coder.
2. `yarn format` pour le formatage.
3. `yarn type-check` — pas d'erreur de types.
4. `yarn build` — le build de production passe.
5. Commit + PR.

## Vérifier le rendu de production en local

```bash
yarn build
yarn preview
```

`yarn preview` sert le `dist/` sur un port local — c'est le contenu exact qui sera servi par nginx en production.

## Tester l'image Docker en local

```bash
docker build -t cofrap-frontend:dev .
docker run --rm -p 8080:8080 cofrap-frontend:dev
# → http://127.0.0.1:8080
```

→ Détails image + déploiement : [`deployment.md`](deployment.md).

## Problèmes courants

Voir [`troubleshooting.md`](troubleshooting.md).
