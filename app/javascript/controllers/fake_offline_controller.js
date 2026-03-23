import { Controller } from "@hotwired/stimulus"

const KEY = "ei_pos_fake_offline"

// Patch at import time — runs before any controller connects, so
// navigator.onLine reads as false for the entire page lifecycle.
if (localStorage.getItem(KEY) === "true") {
  Object.defineProperty(navigator, "onLine", { get: () => false, configurable: true })
}

export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.updateUI()
  }

  get active() {
    return localStorage.getItem(KEY) === "true"
  }

  toggle() {
    localStorage.setItem(KEY, String(!this.active))
    location.reload()
  }

  updateUI() {
    if (!this.hasLabelTarget) return
    if (this.active) {
      this.labelTarget.textContent = "Faking offline"
      this.labelTarget.classList.add("text-amber-400")
      this.element.classList.add("bg-amber-500/10")
    } else {
      this.labelTarget.textContent = "Fake offline"
      this.labelTarget.classList.remove("text-amber-400")
      this.element.classList.remove("bg-amber-500/10")
    }
  }
}
