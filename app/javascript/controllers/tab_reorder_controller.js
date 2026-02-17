import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "register_tab_order"
const DISMISSED_KEY = "register_dismissed_tabs"

/**
 * Enables drag-and-drop reordering of register order tabs.
 * Persists tab order in localStorage so it survives page navigations.
 * Also handles dismissing held-order tabs from the tab bar.
 */
export default class extends Controller {
  static targets = ["tab"]
  static values = { currentOrderId: String }

  connect() {
    this.undismissCurrent()
    this.hideDismissedTabs()
    this.applyStoredOrder()
  }

  // --- Drag handlers ---

  dragstart(event) {
    this.draggedTab = event.currentTarget.closest("[data-tab-reorder-target='tab']")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedTab.dataset.orderId)
    requestAnimationFrame(() => this.draggedTab.classList.add("opacity-50"))
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const tab = event.currentTarget.closest("[data-tab-reorder-target='tab']")
    if (!tab || tab === this.draggedTab) return

    const rect = tab.getBoundingClientRect()
    const midpoint = rect.left + rect.width / 2

    if (event.clientX < midpoint) {
      tab.parentNode.insertBefore(this.draggedTab, tab)
    } else {
      tab.parentNode.insertBefore(this.draggedTab, tab.nextSibling)
    }
  }

  drop(event) {
    event.preventDefault()
    this.saveOrder()
  }

  dragend() {
    if (this.draggedTab) {
      this.draggedTab.classList.remove("opacity-50")
      this.draggedTab = null
    }
  }

  // --- Dismiss held tabs ---

  dismiss(event) {
    event.preventDefault()
    event.stopPropagation()

    const tab = event.currentTarget.closest("[data-tab-reorder-target='tab']")
    const orderId = tab.dataset.orderId
    const dismissed = this.getDismissedIds()
    dismissed.add(orderId)
    localStorage.setItem(DISMISSED_KEY, JSON.stringify([...dismissed]))

    tab.remove()
    this.saveOrder()

    // Navigate to the default register page (will load latest draft)
    window.Turbo.visit(event.currentTarget.dataset.navigatePath)
  }

  getDismissedIds() {
    try {
      const raw = localStorage.getItem(DISMISSED_KEY)
      return raw ? new Set(JSON.parse(raw).map(String)) : new Set()
    } catch (_e) {
      return new Set()
    }
  }

  undismissCurrent() {
    if (!this.currentOrderIdValue) return
    const dismissed = this.getDismissedIds()
    if (dismissed.delete(this.currentOrderIdValue)) {
      localStorage.setItem(DISMISSED_KEY, JSON.stringify([...dismissed]))
    }
  }

  hideDismissedTabs() {
    const dismissed = this.getDismissedIds()
    if (dismissed.size === 0) return

    for (const tab of this.tabTargets) {
      if (dismissed.has(tab.dataset.orderId)) {
        tab.remove()
      }
    }
  }

  // --- Persistence ---

  applyStoredOrder() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (!raw) return

      const storedIds = JSON.parse(raw)
      const tabs = this.tabTargets
      if (tabs.length < 2) return

      const container = tabs[0].parentNode
      const tabMap = new Map(tabs.map(t => [t.dataset.orderId, t]))

      // Tabs in stored order first, then any new tabs at end
      const ordered = []
      for (const id of storedIds) {
        const tab = tabMap.get(String(id))
        if (tab) {
          ordered.push(tab)
          tabMap.delete(String(id))
        }
      }
      for (const tab of tabMap.values()) {
        ordered.push(tab)
      }

      // Re-append in order (before any non-tab children like the New button)
      const firstNonTab = container.querySelector(":scope > :not([data-tab-reorder-target='tab'])")
      for (const tab of ordered) {
        container.insertBefore(tab, firstNonTab)
      }
    } catch (_e) {
      // If parsing fails, keep server order
    }
  }

  saveOrder() {
    const ids = this.tabTargets.map(t => t.dataset.orderId)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(ids))
  }
}
