import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const backend = 'http://localhost:3000'
const proxyPaths = ['/api', '/rails', '/auth', '/dev', '/admin', '/webhooks', '/up']

// Built assets are served by Rails under /app/; the dev server serves the SPA at the root
// so payment return URLs and OAuth redirects (APP_HOST=localhost:5173) land on real routes.
export default defineConfig(({ command }) => ({
  plugins: [react()],
  base: command === 'build' ? '/app/' : '/',
  build: {
    outDir: '../public/app',
    emptyOutDir: true,
    manifest: true,
    rollupOptions: {
      input: {
        main: 'index.html',
        admin: 'src/admin.tsx',
      },
    },
  },
  server: {
    host: true,
    port: 5173,
    proxy: {
      ...Object.fromEntries(proxyPaths.map((p) => [p, { target: backend, changeOrigin: false }])),
      '/cable': { target: backend, changeOrigin: false, ws: true },
    },
  },
}))
