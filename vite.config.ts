import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    vueDevTools(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
  server: {
    // Liaison backend en dev : /api/* est proxifié vers le gateway sur :8080.
    // Démarrer au préalable le backend, au choix :
    //   - docker compose up -d --build  (stack locale du dépôt backend, recommandé)
    //   - kubectl -n openfaas port-forward svc/gateway 8080:8080  (cluster OpenFaaS)
    // Le `rewrite` strippe /api → le gateway reçoit /function/<name>.
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
})
