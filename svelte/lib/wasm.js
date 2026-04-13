/**
 * WASM interface for the Svelte offline app.
 *
 * Manages the lifecycle of the Rails WASM web worker and exposes a clean
 * async API for seeding data and calculating order totals.
 */

let worker = null
let bootPromise = null
let bootResolve = null
let bootReject = null
let callId = 0
const pending = new Map()
const progressListeners = []

function getWorker() {
  if (!worker) {
    // Use BASE_URL + the known entry filename rather than `new URL(...)`.
    // Vite's `new URL("./file.js", import.meta.url)` pattern produces a
    // hashed asset reference that changes on every rebuild, causing 404s
    // when bundle.js is cached. wasm-worker.js is an explicit entry point
    // (entryFileNames: "[name].js") so its path is always stable.
    worker = new Worker(`${import.meta.env.BASE_URL}wasm-worker.js`, {
      type: "module",
    })
    worker.onmessage = (e) => handleMessage(e.data)
    worker.onerror = (err) => {
      bootReject?.(err)
    }
  }
  return worker
}

function handleMessage(msg) {
  if (msg.type === "ready") {
    bootResolve?.()
  } else if (msg.type === "progress") {
    progressListeners.forEach((cb) => cb(msg.step))
  } else if (msg.type === "result" || msg.type === "seeded") {
    const cb = pending.get(msg.id)
    if (cb) {
      cb.resolve(msg.result ?? null)
      pending.delete(msg.id)
    }
  } else if (msg.type === "error") {
    if (msg.id != null) {
      const cb = pending.get(msg.id)
      if (cb) {
        cb.reject(new Error(msg.error))
        pending.delete(msg.id)
      }
    } else {
      bootReject?.(new Error(msg.error))
    }
  }
}

/** Subscribe to boot progress messages. Returns an unsubscribe function. */
export function onWasmProgress(callback) {
  progressListeners.push(callback)
  return () => {
    const i = progressListeners.indexOf(callback)
    if (i >= 0) progressListeners.splice(i, 1)
  }
}

/** Boot the Rails WASM worker. Idempotent — safe to call multiple times. */
export function bootWasm() {
  if (bootPromise) return bootPromise
  bootPromise = new Promise((resolve, reject) => {
    bootResolve = resolve
    bootReject = reject
  })
  getWorker().postMessage({ type: "boot" })
  return bootPromise
}

/**
 * Seed PGlite with tax codes so the Rails VM can look them up during calculation.
 * taxCodes: array of { id, code, name, rate } objects (from IndexedDB sync).
 */
export async function seedTaxCodes(taxCodes) {
  await bootPromise
  const id = ++callId
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    worker.postMessage({ type: "seed_tax_codes", id, taxCodes })
  })
}

/**
 * Calculate order totals using Rails business logic running in WASM.
 * lines: array of { name, unit_price, quantity, tax_code_id }
 * Returns: { subtotal, tax_total, discount_total, total, lines: [...] }
 */
export async function calculateOrderTotal(lines) {
  await bootPromise
  const id = ++callId
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    // JSON round-trip strips Svelte 5 reactive proxies, which can't be
    // serialized by the structured clone algorithm used by postMessage.
    worker.postMessage({ type: "calculate", id, lines: JSON.parse(JSON.stringify(lines)) })
  })
}
