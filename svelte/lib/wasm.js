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
    worker = new Worker(new URL("../wasm-worker.js", import.meta.url), {
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
    worker.postMessage({ type: "calculate", id, lines })
  })
}
