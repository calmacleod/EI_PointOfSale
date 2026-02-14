import { Controller } from "@hotwired/stimulus"

const STORAGE_PREFIX = "table_filters_"

export default class extends Controller {
  static values = {
    storageKey: String,
    searchPath: String,
    filterParams: { type: Array, default: [ "q" ] }
  }

  connect() {
    this.boundSubmit = this.saveFiltersOnSubmit.bind(this)
    this.form = this.element.querySelector("form")
    if (this.form) {
      this.form.addEventListener("submit", this.boundSubmit)
    }

    this.maybeRedirectToStoredFilters()
    this.saveFiltersFromUrl()
  }

  disconnect() {
    if (this.form) {
      this.form.removeEventListener("submit", this.boundSubmit)
    }
  }

  get storageKey() {
    return `${STORAGE_PREFIX}${this.storageKeyValue || "default"}`
  }

  getStoredFilters() {
    try {
      const raw = localStorage.getItem(this.storageKey)
      return raw ? JSON.parse(raw) : {}
    } catch (_e) {
      return {}
    }
  }

  setStoredFilters(filters) {
    const cleaned = Object.fromEntries(
      Object.entries(filters).filter(([ , v ]) => v != null && v !== "")
    )
    if (Object.keys(cleaned).length === 0) {
      localStorage.removeItem(this.storageKey)
    } else {
      localStorage.setItem(this.storageKey, JSON.stringify(cleaned))
    }
  }

  getFiltersFromForm() {
    if (!this.form) return {}
    const params = new URLSearchParams(new FormData(this.form))
    const filterParams = this.filterParamsValue || [ "q" ]
    const filters = {}
    for (const name of filterParams) {
      const value = params.get(name)
      if (value !== null) filters[name] = value
    }
    return filters
  }

  getFiltersFromUrl() {
    const params = new URLSearchParams(window.location.search)
    const filterParams = this.filterParamsValue || [ "q" ]
    const filters = {}
    for (const name of filterParams) {
      const value = params.get(name)
      if (value !== null) filters[name] = value
    }
    return filters
  }

  hasActiveFiltersInUrl() {
    const filters = this.getFiltersFromUrl()
    return Object.keys(filters).length > 0
  }

  saveFiltersOnSubmit(event) {
    const filters = this.getFiltersFromForm()
    this.setStoredFilters(filters)
  }

  saveFiltersFromUrl() {
    if (this.hasActiveFiltersInUrl()) {
      this.setStoredFilters(this.getFiltersFromUrl())
    }
  }

  maybeRedirectToStoredFilters() {
    if (!this.hasActiveFiltersInUrl()) {
      const stored = this.getStoredFilters()
      if (Object.keys(stored).length > 0) {
        const url = new URL(this.searchPathValue || window.location.pathname, window.location.origin)
        for (const [ key, value ] of Object.entries(stored)) {
          url.searchParams.set(key, value)
        }
        window.location.href = url.toString()
      }
    }
  }

  clearFilters() {
    localStorage.removeItem(this.storageKey)
    const url = this.searchPathValue || window.location.pathname
    window.location.href = url
  }
}
