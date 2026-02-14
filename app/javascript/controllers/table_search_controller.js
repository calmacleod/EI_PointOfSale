import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300

export default class extends Controller {
  static targets = ["form", "input"]

  connect() {
    this.boundInput = this.handleInput.bind(this)
    this.debounceTimer = null
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener("input", this.boundInput)
    }
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
  }

  handleChange() {
    this.submitSearch()
  }

  submitSearch() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}
