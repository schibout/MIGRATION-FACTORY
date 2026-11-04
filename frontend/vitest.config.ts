import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Tests du frontend uniquement : API simulee, aucun serveur SAP/PostgreSQL.
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    environmentOptions: { jsdom: { url: 'http://localhost/' } },
    env: { VITE_API_BASE_URL: 'http://invalid.test', VITE_API_URL: 'http://invalid.test' },
    include: ['tests/**/*.test.{ts,tsx}'],
    setupFiles: ['./tests/setup.ts'],
    threads: false,
    clearMocks: true,
    mockReset: true,
    restoreMocks: true,
    testTimeout: 10000,
  },
});
