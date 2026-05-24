import { globalIgnores } from 'eslint/config'
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import pluginVue from 'eslint-plugin-vue'
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'

// Configuration ESLint (flat config) — lint des fichiers TypeScript et Vue.
// Le *formatage* reste délégué à Prettier (`yarn format` / `yarn format:check`) :
// `skipFormatting` désactive les règles ESLint qui entreraient en conflit.
export default defineConfigWithVueTs(
  {
    name: 'app/files-to-lint',
    files: ['**/*.{ts,mts,tsx,vue}'],
  },

  globalIgnores(['**/dist/**', '**/dist-ssr/**', '**/coverage/**']),

  pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,

  // Renforcement TypeScript : interdit `any` explicite (force à typer
  // correctement, y compris via `unknown` + narrowing si nécessaire).
  // `vueTsConfigs.recommended` met cette règle en `warn` par défaut — on la
  // passe en `error` pour bloquer la CI sur les régressions.
  {
    name: 'app/strict-typing',
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
    },
  },

  skipFormatting,
)
