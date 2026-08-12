import { svelte } from "@sveltejs/vite-plugin-svelte"
import inertia from "@inertiajs/vite"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"
import path from "node:path"

export default defineConfig({
  build: { emptyOutDir: true },
  plugins: [tailwindcss(), RubyPlugin(), inertia(), svelte()],
  resolve: {
    alias: {
      $lib: path.resolve("./app/javascript/lib"),
    },
  },
})
