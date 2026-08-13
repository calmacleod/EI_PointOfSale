import { svelte } from "@sveltejs/vite-plugin-svelte"
import inertia from "@inertiajs/vite"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig, type ConfigEnv, type Plugin, type UserConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"
import path from "node:path"

const rubyPlugins = RubyPlugin() as Plugin[]
const rubyConfigPlugin = rubyPlugins.find((plugin) => plugin.name === "vite-plugin-ruby")
const configureRuby = rubyConfigPlugin?.config

if (rubyConfigPlugin && typeof configureRuby === "function") {
  rubyConfigPlugin.config = function (userConfig: UserConfig, env: ConfigEnv) {
    const config = configureRuby.call(this, userConfig, env) as UserConfig
    const server = config.server
    const hmr = server?.hmr

    // vite-plugin-ruby 5.2.2 still emits the deprecated server.hmr.clientPort.
    // Move websocket options to their Vite 8 home while preserving hmr.overlay.
    if (hmr && typeof hmr === "object") {
      const { overlay, ...ws } = hmr
      server.ws = { ...server.ws, ...ws }
      if (overlay === undefined) delete server.hmr
      else server.hmr = { overlay }
    }

    return config
  }
}

export default defineConfig({
  build: { emptyOutDir: true },
  plugins: [tailwindcss(), ...rubyPlugins, inertia(), svelte()],
  resolve: {
    alias: {
      $lib: path.resolve("./app/javascript/lib"),
    },
  },
})
