import { defineConfig } from 'vite';

export default defineConfig({
  base: process.env.BASE_URL ?? '/',
  server: {
    port: 3001,
    open: true,
  },
  optimizeDeps: {
    exclude: ['@gasm-compiler/core', 'assemblyscript'],
    esbuildOptions: {
      target: 'esnext',
    },
  },
  build: {
    target: 'esnext',
  },
});
