import { Controller } from "@hotwired/stimulus"
import { syncProducts } from "../lib/sync.js"

const SYNC_INTERVAL_MS = 5 * 60 * 1000 // 5 minutes

export default class extends Controller {
  connect() {
    this.runSync()
    this.intervalId = setInterval(() => this.runSync(), SYNC_INTERVAL_MS)
  }

  disconnect() {
    if (this.intervalId) clearInterval(this.intervalId)
  }

  async runSync() {
    if (!navigator.onLine) return
    try {
      const result = await syncProducts()
      window.dispatchEvent(new CustomEvent("offline-sync:synced", { detail: result }))
    } catch {
      // Silently swallow — user may be offline or not yet visited /offline
    }
  }
}
