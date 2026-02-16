import { Controller } from "@hotwired/stimulus"

const STORAGE_PREFIX = "table_columns_"

/**
 * Manages column visibility for data tables.
 * Reads column definitions from a JSON data attribute, persists
 * preferences in localStorage, and toggles column visibility via
 * a dynamic <style> element.
 */
export default class extends Controller {
  static targets = ["popover", "table"]
  static values = {
    resource: String,
    columns: { type: Array, default: [] }
  }

  connect() {
    this.styleEl = document.createElement("style")
    document.head.appendChild(this.styleEl)

    this.applyStoredPreferences()

    this.boundClose = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    if (this.styleEl && this.styleEl.parentNode) {
      this.styleEl.parentNode.removeChild(this.styleEl)
    }
    document.removeEventListener("click", this.boundClose)
  }

  // --- Popover ---

  togglePopover(event) {
    event.stopPropagation()
    if (this.hasPopoverTarget) {
      this.popoverTarget.classList.toggle("hidden")
    }
  }

  closeOnOutsideClick(event) {
    if (!this.hasPopoverTarget) return
    if (this.element.contains(event.target)) return
    this.popoverTarget.classList.add("hidden")
  }

  // --- Column toggle ---

  toggleColumn(event) {
    const key = event.currentTarget.dataset.columnKey
    const visible = event.currentTarget.checked
    this.setColumnVisibility(key, visible)
    this.savePreferences()
  }

  resetDefaults() {
    localStorage.removeItem(this.storageKey)
    const defaults = this.columnsValue.filter(c => c.default).map(c => c.key)
    this.applyVisibility(defaults)
    this.syncCheckboxes(defaults)
  }

  // --- Visibility ---

  setColumnVisibility(key, visible) {
    const current = this.getVisibleColumns()
    const updated = visible
      ? [...new Set([...current, key])]
      : current.filter(k => k !== key)
    this.applyVisibility(updated)
  }

  applyVisibility(visibleKeys) {
    const allKeys = this.columnsValue.map(c => c.key)
    const hiddenKeys = allKeys.filter(k => !visibleKeys.includes(k))

    const rules = hiddenKeys.map(key =>
      `[data-column="${key}"] { display: none !important; }`
    ).join("\n")

    this.styleEl.textContent = rules
  }

  getVisibleColumns() {
    const allKeys = this.columnsValue.map(c => c.key)
    const checkboxes = this.element.querySelectorAll("input[type=checkbox][data-column-key]")
    const visible = []
    checkboxes.forEach(cb => {
      if (cb.checked) visible.push(cb.dataset.columnKey)
    })
    return visible.length > 0 ? visible : allKeys
  }

  // --- Persistence ---

  get storageKey() {
    return `${STORAGE_PREFIX}${this.resourceValue || "default"}`
  }

  savePreferences() {
    const visible = this.getVisibleColumns()
    localStorage.setItem(this.storageKey, JSON.stringify(visible))
  }

  applyStoredPreferences() {
    try {
      const raw = localStorage.getItem(this.storageKey)
      if (raw) {
        const visible = JSON.parse(raw)
        this.applyVisibility(visible)
        this.syncCheckboxes(visible)
      } else {
        // Apply defaults
        const defaults = this.columnsValue.filter(c => c.default).map(c => c.key)
        this.applyVisibility(defaults)
        this.syncCheckboxes(defaults)
      }
    } catch (_e) {
      // If parsing fails, show all columns
    }
  }

  syncCheckboxes(visibleKeys) {
    const checkboxes = this.element.querySelectorAll("input[type=checkbox][data-column-key]")
    checkboxes.forEach(cb => {
      cb.checked = visibleKeys.includes(cb.dataset.columnKey)
    })
  }
}
