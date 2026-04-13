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
    chunkSizeWarningLimit: 5000,
    rollupOptions: {
      input: {
        bundle: resolve(__dirname, "main.js"),
        sync: resolve(__dirname, "sync-worker.js"),
        "wasm-worker": resolve(__dirname, "wasm-worker.js"),
      },
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "[name].js",
        assetFileNames: "[name].[ext]",
      },
      onwarn(warning, warn) {
        // PGlite uses eval internally — nothing we can change
        if (warning.code === "EVAL" && warning.id?.includes("pglite")) return
        // PGlite assets (postgres.wasm, postgres.data) are emitted once per entry
        // point but are identical — the last write wins and the output is correct
        if (warning.code === "FILE_NAME_CONFLICT") return
        warn(warning)
      },
    },
  },
  // Required for SharedArrayBuffer / WASM threading
  server: {
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    },
  },
  base: "/offline/",
  optimizeDeps: {
    exclude: ["@electric-sql/pglite"],
  },
})
