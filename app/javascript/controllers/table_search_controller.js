import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300

export default class extends Controller {
  static targets = ["form", "input", "clear"]

  connect() {
    this.boundInput = this.handleInput.bind(this)
    this.debounceTimer = null
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener("input", this.boundInput)
    }
    this.toggleClearButton()
  }

  disconnect() {
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener("input", this.boundInput)
    }
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  handleInput() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submitSearch(), DEBOUNCE_MS)
    this.toggleClearButton()
  }

  handleChange() {
    this.submitSearch()
    this.toggleClearButton()
  }

  submitSearch() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  toggleClearButton() {
    if (!this.hasClearTarget) return

    const hasValues = this.formHasValues()
    this.clearTarget.classList.toggle("hidden", !hasValues)
  }

  formHasValues() {
    if (!this.hasFormTarget) return false
    const data = new FormData(this.formTarget)
    for (const [, value] of data) {
      if (value != null && value !== "") return true
    }
    return false
  }
}
