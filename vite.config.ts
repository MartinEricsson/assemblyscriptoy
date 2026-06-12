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
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/assemblyscript') || id.includes('node_modules/binaryen')) {
            return 'assemblyscript';
          }
          if (
            id.includes('@gasm-compiler/core') ||
            id.includes('/src/gasm-integrator') ||
            id.includes('/src/browser-gpu-executor')
          ) {
            return 'gasm';
          }
        },
      },
    },
  },
});
