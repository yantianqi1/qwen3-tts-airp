import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 3019,
    proxy: {
      '/api': {
        target: 'http://localhost:8019',
        changeOrigin: true,
      },
      '/audio': {
        target: 'http://localhost:8019',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
  },
})
