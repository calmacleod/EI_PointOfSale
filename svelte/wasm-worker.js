/**
 * WASM Web Worker
 *
 * Boots the Rails app compiled to WebAssembly (app.wasm) inside a Web Worker,
 * using PGlite as the in-browser Postgres database. Once booted, handles
 * messages from the Svelte app to seed data and calculate order totals.
 *
 * Message protocol:
 *   { type: 'boot' }                             → { type: 'ready' } | { type: 'error', error }
 *   { type: 'seed_tax_codes', id, taxCodes }     → { type: 'seeded', id } | { type: 'error', id, error }
 *   { type: 'get_tax_codes', id }                → { type: 'result', id, result } | { type: 'error', id, error }
 *   { type: 'calculate', id, lines }             → { type: 'result', id, result } | { type: 'error', id, error }
 */

import { initRailsVM, registerPGliteWasmInterface, RackHandler } from "wasmify-rails"
import { PGlite } from "@electric-sql/pglite"

let vm = null
let rackHandler = null

function progress(step) {
  self.postMessage({ type: "progress", step })
}

async function boot() {
  progress("Initializing PGlite...")
  const pg = new PGlite()
  registerPGliteWasmInterface(self, pg)

  progress("Loading Rails WASM (app.wasm)...")
  vm = await initRailsVM("/app.wasm", {
    database: { adapter: "pglite" },
    progressCallback: (step) => progress(step),
  })

  progress("Preparing database schema...")
  // Load the primary schema directly — avoids the migration infrastructure entirely
  // and prevents Rails from touching queue/cache/cable database connections.
  // evalAsync is required because PGlite queries return Promises and the Ruby
  // pglite adapter calls JS::Object#await, which only works inside evalAsync/callAsync.
  await vm.evalAsync('ActiveRecord::Schema.verbose = false; load "#{Rails.root}/db/schema.rb"')

  // RackHandler dispatches HTTP requests through the full Rails Rack stack.
  // async: true uses proc.callAsync("call") so JS::Object#await works inside Ruby.
  // cache: false because we want live results for order calculations.
  rackHandler = new RackHandler(() => Promise.resolve(vm), { cache: false, async: true })

  progress("Rails WASM ready!")
}

self.onmessage = async (e) => {
  const { type, id } = e.data

  if (type === "boot") {
    try {
      await boot()
      self.postMessage({ type: "ready" })
    } catch (err) {
      self.postMessage({ type: "error", error: err.message })
    }
    return
  }

  if (type === "seed_tax_codes") {
    const { taxCodes } = e.data
    try {
      const response = await rackHandler.handle(
        new Request(`${self.location.origin}/wasm/tax_codes`, {
          method: "POST",
          body: JSON.stringify({ tax_codes: taxCodes }),
          headers: { "Content-Type": "application/json", Accept: "application/json" },
        }),
      )
      if (!response.ok) throw new Error(`Seed failed: ${response.status}`)
      self.postMessage({ type: "seeded", id })
    } catch (err) {
      self.postMessage({ type: "error", id, error: err.message })
    }
    return
  }

  if (type === "get_tax_codes") {
    try {
      const response = await rackHandler.handle(
        new Request(`${self.location.origin}/wasm/tax_codes`, {
          headers: { Accept: "application/json" },
        }),
      )
      const result = await response.json()
      self.postMessage({ type: "result", id, result })
    } catch (err) {
      self.postMessage({ type: "error", id, error: err.message })
    }
    return
  }

  if (type === "calculate") {
    // POST to the /wasm/orders/calculate Rails endpoint running inside app.wasm.
    const { lines } = e.data
    try {
      const response = await rackHandler.handle(
        new Request(`${self.location.origin}/wasm/orders/calculate`, {
          method: "POST",
          body: JSON.stringify({ lines }),
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
          },
        }),
      )
      const result = await response.json()
      self.postMessage({ type: "result", id, result })
    } catch (err) {
      self.postMessage({ type: "error", id, error: err.message })
    }
  }
}
