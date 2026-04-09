import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import { fileURLToPath } from "url"
import { dirname, resolve } from "path"

const __dirname = dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [react()],
  root: __dirname,
  build: {
    outDir: resolve(__dirname, "../public/inertia"),
    emptyOutDir: true,
    rollupOptions: {
      input: { app: resolve(__dirname, "app.jsx") },
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "[name].js",
        assetFileNames: "[name].[ext]",
      },
    },
  },
  base: "/inertia/",
})
