import react from '@vitejs/plugin-react'
import path from 'path'
import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig({
  // Prefixe de deploiement : '/app4/' derriere le nginx de l'hote (point d'entree
  // unique), '/' si l'application est servie a la racine. Vite s'en sert pour les
  // assets ET pour le chemin du client HMR ; le code applicatif le relit via
  // import.meta.env.BASE_URL (cf. src/basePath.ts).
  base: process.env.APP_BASE || '/',
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 8080,
    host: '0.0.0.0',
    // Derriere le nginx de l'hote, le navigateur ne voit que le port 80 : sans
    // clientPort, le client HMR tenterait ws://<hote>:3000/ (port binde sur la
    // loopback, ferme au reseau) et bouclerait sur des erreurs de reconnexion.
    // HMR_CLIENT_PORT absent => comportement Vite par defaut (acces direct).
    hmr: process.env.HMR_CLIENT_PORT
      ? { clientPort: Number(process.env.HMR_CLIENT_PORT) }
      : undefined,
    proxy: {
      '/api': {
        target: process.env.API_URL || 'http://localhost:5000',
        changeOrigin: true,
        secure: false,
        // Supprimé le rewrite pour garder /api dans l'URL
      }
    }
  }
})