import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300
const STORAGE_PREFIX = "table_filters_"
const PATH_MAP_KEY = "table_filter_paths"

/**
 * Manages the generic filter bar: search input, add/remove filter chips,
 * form submission via Turbo Frame, and localStorage persistence.
 * Filter chips are fetched server-side and rendered dynamically.
 */
export default class extends Controller {
  static targets = ["form", "searchInput", "clearButton", "chipsContainer",
                     "addFilterWrapper", "addFilterDropdown"]
  static values = {
    resource: String,
    searchPath: String,
    filters: { type: Array, default: [] },
    activeKeys: { type: Array, default: [] },
    turboFrame: String
  }

  connect() {
    this.debounceTimer = null
    this.registerPath()
    this.maybeRestoreFromStorage()
    this.updateClearVisibility()

    // Close dropdown when clicking outside
    this.boundCloseDropdown = this.closeAddFilterDropdown.bind(this)
    document.addEventListener("click", this.boundCloseDropdown)
  }

  disconnect() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    document.removeEventListener("click", this.boundCloseDropdown)
  }

  // --- Search ---

  handleSearchInput() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submitForm(), DEBOUNCE_MS)
  }

  // --- Add filter dropdown ---

  toggleAddFilter(event) {
    event.stopPropagation()
    if (this.hasAddFilterDropdownTarget) {
      this.addFilterDropdownTarget.classList.toggle("hidden")
    }
  }

  closeAddFilterDropdown(event) {
    if (!this.hasAddFilterDropdownTarget) return
    if (!this.hasAddFilterWrapperTarget) return
    if (this.addFilterWrapperTarget.contains(event.target)) return
    this.addFilterDropdownTarget.classList.add("hidden")
  }

  async addFilter(event) {
    const key = event.currentTarget.dataset.filterKey
    const filterDef = this.filtersValue.find(f => f.key === key)
    if (!filterDef) return

    // Hide dropdown
    if (this.hasAddFilterDropdownTarget) {
      this.addFilterDropdownTarget.classList.add("hidden")
    }

    // Fetch and insert chip HTML from server
    try {
      const formId = this.formId
      const url = `/filters/chip?resource=${encodeURIComponent(this.resourceValue)}&key=${encodeURIComponent(key)}&form_id=${encodeURIComponent(formId)}`
      const response = await fetch(url, { headers: { "Accept": "text/html" } })

      if (response.ok) {
        const html = await response.text()
        if (this.hasChipsContainerTarget) {
          this.chipsContainerTarget.classList.remove("hidden")
          this.chipsContainerTarget.insertAdjacentHTML("beforeend", html)
        }

        // Disable the dropdown option
        event.currentTarget.disabled = true

        // Track active key
        this.activeKeysValue = [...this.activeKeysValue, key]
        this.updateClearVisibility()
      }
    } catch (e) {
      console.error("Failed to fetch filter chip:", e)
    }
  }

  // --- Remove filter ---

  removeFilter(event) {
    const key = event.currentTarget.dataset.filterKey
    const chipEl = this.hasChipsContainerTarget
      ? this.chipsContainerTarget.querySelector(`[data-filter-key="${key}"]`)
      : null
    if (chipEl) chipEl.remove()

    // Clear hidden/named inputs for this filter
    this.clearFilterParams(key)

    // Re-enable the dropdown option
    if (this.hasAddFilterDropdownTarget) {
      const btn = this.addFilterDropdownTarget.querySelector(`[data-filter-key="${key}"]`)
      if (btn) btn.disabled = false
    }

    // Track active key removal
    this.activeKeysValue = this.activeKeysValue.filter(k => k !== key)

    // Hide chips container if empty
    if (this.hasChipsContainerTarget && this.chipsContainerTarget.children.length === 0) {
      this.chipsContainerTarget.classList.add("hidden")
    }

    this.submitForm()
    this.updateClearVisibility()
  }

  // --- Filter change ---

  handleFilterChange() {
    this.submitForm()
    this.updateClearVisibility()
  }

  // --- Clear all ---

  clearAll() {
    localStorage.removeItem(this.storageKey)
    this.unregisterPath()
    window.location.href = this.searchPathValue || window.location.pathname
  }

  // --- Form submission ---

  submitForm() {
    if (this.hasFormTarget) {
      this.saveToStorage()
      this.formTarget.requestSubmit()
    }
  }

  // --- localStorage persistence ---

  get storageKey() {
    return `${STORAGE_PREFIX}${this.resourceValue || "default"}`
  }

  saveToStorage() {
    if (!this.hasFormTarget) return
    const formData = new FormData(this.formTarget)
    const filters = {}
    for (const [key, value] of formData) {
      if (value == null || value === "") continue
      if (key.endsWith("[]")) {
        const base = key
        filters[base] = filters[base] || []
        filters[base].push(value)
      } else {
        filters[key] = value
      }
    }
    if (Object.keys(filters).length === 0) {
      localStorage.removeItem(this.storageKey)
      this.unregisterPath()
    } else {
      localStorage.setItem(this.storageKey, JSON.stringify(filters))
      this.registerPath()
    }
  }

  maybeRestoreFromStorage() {
    const urlParams = new URLSearchParams(window.location.search)
    const hasUrlFilters = Array.from(urlParams.values()).some(v => v !== "")
    if (hasUrlFilters) {
      this.saveToStorage()
      return
    }

    // If no URL params but localStorage has stored filters, restore them.
    // Use Turbo.visit with "replace" to avoid a flash and keep history clean.
    try {
      const raw = localStorage.getItem(this.storageKey)
      if (!raw) return
      const stored = JSON.parse(raw)
      if (Object.keys(stored).length === 0) return

      const url = new URL(this.searchPathValue || window.location.pathname, window.location.origin)
      for (const [key, value] of Object.entries(stored)) {
        if (Array.isArray(value)) {
          value.forEach(v => url.searchParams.append(key, v))
        } else {
          url.searchParams.set(key, value)
        }
      }

      if (window.Turbo) {
        window.Turbo.visit(url.toString(), { action: "replace" })
      } else {
        window.location.replace(url.toString())
      }
    } catch (_e) {
      // Ignore parse errors
    }
  }

  // --- Helpers ---

  updateClearVisibility() {
    if (!this.hasClearButtonTarget) return
    const hasSearch = this.hasSearchInputTarget && this.searchInputTarget.value.trim() !== ""
    const hasFilters = this.activeKeysValue.length > 0
    this.clearButtonTarget.classList.toggle("hidden", !hasSearch && !hasFilters)
  }

  clearFilterParams(key) {
    const filterDef = this.filtersValue.find(f => f.key === key)
    if (!filterDef) return

    const paramKeys = filterDef.paramKeys || [key]
    paramKeys.forEach(pk => {
      const inputs = this.element.querySelectorAll(`[name="${pk}"]`)
      inputs.forEach(input => {
        if (input.type === "checkbox") {
          input.checked = false
        } else {
          input.value = ""
        }
      })
    })
  }

  get formId() {
    return this.hasFormTarget ? this.formTarget.id : `${this.resourceValue}_filter_form`
  }

  // --- Path registration for turbo:before-visit interception ---

  registerPath() {
    try {
      const pathMap = JSON.parse(localStorage.getItem(PATH_MAP_KEY) || "{}")
      const pathname = new URL(this.searchPathValue || window.location.pathname, window.location.origin).pathname
      pathMap[pathname] = this.storageKey
      localStorage.setItem(PATH_MAP_KEY, JSON.stringify(pathMap))
    } catch (_e) { /* ignore */ }
  }

  unregisterPath() {
    try {
      const pathMap = JSON.parse(localStorage.getItem(PATH_MAP_KEY) || "{}")
      const pathname = new URL(this.searchPathValue || window.location.pathname, window.location.origin).pathname
      delete pathMap[pathname]
      localStorage.setItem(PATH_MAP_KEY, JSON.stringify(pathMap))
    } catch (_e) { /* ignore */ }
  }
}
