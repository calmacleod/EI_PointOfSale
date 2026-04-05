import { defineConfig } from "vite"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import { fileURLToPath } from "url"
import { dirname, resolve } from "path"

const __dirname = dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [svelte()],
  root: __dirname,
  build: {
    outDir: resolve(__dirname, "../public/offline"),
    emptyOutDir: true,
    rollupOptions: {
      preserveEntrySignatures: false,
      input: {
        bundle: resolve(__dirname, "main.js"),
        sync: resolve(__dirname, "sync-worker.js"),
      },
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "chunk-[hash].js",
        assetFileNames: "[name].[ext]",
      },
    },
  },
  base: "/offline/",
})
