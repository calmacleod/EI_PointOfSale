import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "button"]

  async connect() {
    await this.refresh()
    // Re-render whenever a background sync completes
    window.addEventListener("offline-sync:synced", this.onSynced)
  }

  disconnect() {
    window.removeEventListener("offline-sync:synced", this.onSynced)
  }

  onSynced = async () => {
    await this.refresh()
  }

  async sync() {
    if (this.syncing) return
    this.syncing = true
    this.buttonTarget.disabled = true
    this.labelTarget.textContent = "Syncing…"

    try {
      const { syncProducts } = await import("/offline/sync.js")
      await syncProducts()
      await this.refresh()
    } catch {
      this.labelTarget.textContent = navigator.onLine ? "Sync failed" : "Offline"
    } finally {
      this.syncing = false
      this.buttonTarget.disabled = false
    }
  }

  async refresh() {
    try {
      const { getLastSyncedAt, getProductCount } = await import("/offline/sync.js")
      const [ts, count] = await Promise.all([getLastSyncedAt(), getProductCount()])
      if (count === 0) {
        this.labelTarget.textContent = "Not synced"
      } else {
        this.labelTarget.textContent = `${count} products · ${this.relativeTime(ts)}`
      }
    } catch {
      this.labelTarget.textContent = "Unavailable"
    }
  }

  relativeTime(iso) {
    if (!iso) return "never"
    const diff = Math.floor((Date.now() - new Date(iso)) / 1000)
    if (diff < 60) return "just now"
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
    return `${Math.floor(diff / 86400)}d ago`
  }
}
