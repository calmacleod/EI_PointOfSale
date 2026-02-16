import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300
const STORAGE_PREFIX = "table_filters_"
const PATH_MAP_KEY = "table_filter_paths"

/**
 * Manages the generic filter bar: search input, add/remove filter chips,
 * form submission via Turbo Frame, and localStorage persistence.
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

  addFilter(event) {
    const key = event.currentTarget.dataset.filterKey
    const filterDef = this.filtersValue.find(f => f.key === key)
    if (!filterDef) return

    // Hide dropdown
    if (this.hasAddFilterDropdownTarget) {
      this.addFilterDropdownTarget.classList.add("hidden")
    }

    // Build and insert chip HTML
    const chip = this.buildChipHTML(filterDef)
    if (this.hasChipsContainerTarget) {
      this.chipsContainerTarget.classList.remove("hidden")
      this.chipsContainerTarget.insertAdjacentHTML("beforeend", chip)
    }

    // Disable the dropdown option
    event.currentTarget.disabled = true

    // Track active key
    this.activeKeysValue = [...this.activeKeysValue, key]
    this.updateClearVisibility()
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

  buildChipHTML(filterDef) {
    const key = filterDef.key
    const label = filterDef.label
    const fid = this.formId
    const removeBtn = `<button type="button" data-action="click->filter-builder#removeFilter" data-filter-key="${key}" class="ml-0.5 text-muted hover:text-body" title="Remove filter"><svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg></button>`
    const chipClass = "inline-flex items-center gap-1 rounded-full border border-theme bg-[var(--color-border)]/20 px-2 py-0.5"

    let inner = ""
    switch (filterDef.type) {
    case "association":
    case "select": {
      const options = (filterDef.choices || []).map(c =>
        `<option value="${c.value}">${this.escapeHTML(c.label)}</option>`
      ).join("")
      inner = `<select name="${key}" form="${fid}" class="appearance-none border-0 bg-transparent py-0 pl-0 pr-4 text-xs font-medium text-body focus:ring-0" data-action="change->filter-builder#handleFilterChange">${options}</select>`
      break
    }
    case "boolean":
      inner = `<select name="${key}" form="${fid}" class="appearance-none border-0 bg-transparent py-0 pl-0 pr-4 text-xs font-medium text-body focus:ring-0" data-action="change->filter-builder#handleFilterChange"><option value="true">Yes</option><option value="false">No</option></select>`
      break
    case "number_range":
      inner = `<input type="number" name="${key}_min" form="${fid}" placeholder="min" step="any" class="w-16 border-0 bg-transparent px-1 py-0 text-xs font-medium text-body focus:ring-0" data-action="change->filter-builder#handleFilterChange"><span class="text-xs text-muted">–</span><input type="number" name="${key}_max" form="${fid}" placeholder="max" step="any" class="w-16 border-0 bg-transparent px-1 py-0 text-xs font-medium text-body focus:ring-0" data-action="change->filter-builder#handleFilterChange">`
      break
    case "date_range": {
      const presets = (filterDef.presets || []).map(p =>
        `<option value="${p.value}">${this.escapeHTML(p.label)}</option>`
      ).join("")
      inner = `<select name="${key}_preset" form="${fid}" class="appearance-none border-0 bg-transparent py-0 pl-0 pr-4 text-xs font-medium text-body focus:ring-0" data-controller="date-range-filter" data-date-range-filter-target="presetSelect" data-action="change->date-range-filter#presetChanged change->filter-builder#handleFilterChange">${presets}</select><div data-date-range-filter-target="customFields" class="hidden flex items-center gap-1"><input type="date" name="${key}_from" form="${fid}" class="input-field-compact h-6 w-28 px-1 py-0 text-xs" data-action="change->filter-builder#handleFilterChange"><span class="text-xs text-muted">–</span><input type="date" name="${key}_to" form="${fid}" class="input-field-compact h-6 w-28 px-1 py-0 text-xs" data-action="change->filter-builder#handleFilterChange"></div>`
      break
    }
    case "multi_select": {
      const checkboxes = (filterDef.choices || []).map(c =>
        `<label class="flex cursor-pointer items-center gap-2 px-3 py-1 text-sm text-body hover:bg-[var(--color-border)]"><input type="checkbox" name="${key}[]" value="${c.value}" form="${fid}" class="rounded border-theme text-accent focus:ring-accent" data-action="change->multi-select-filter#changed change->filter-builder#handleFilterChange">${this.escapeHTML(c.label)}</label>`
      ).join("")
      inner = `<button type="button" data-action="click->multi-select-filter#toggle" class="inline-flex items-center gap-0.5 text-xs font-medium text-body"><span data-multi-select-filter-target="label">Select\u2026</span><svg class="h-3 w-3 text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg></button><div data-multi-select-filter-target="dropdown" class="absolute left-0 top-full z-20 mt-1 hidden max-h-60 min-w-[200px] overflow-y-auto rounded-lg border border-theme bg-surface py-1 shadow-lg">${checkboxes}</div>`
      return `<div class="relative ${chipClass}" data-filter-key="${key}" data-controller="multi-select-filter"><span class="text-xs font-medium text-muted">${this.escapeHTML(label)}:</span>${inner}${removeBtn}</div>`
    }
    }

    return `<div class="${chipClass}" data-filter-key="${key}"><span class="text-xs font-medium text-muted">${this.escapeHTML(label)}:</span>${inner}${removeBtn}</div>`
  }

  escapeHTML(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
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
