import { Controller } from "@hotwired/stimulus"

// Manages the payment form: shows cash-specific fields and calculates change.
export default class extends Controller {
  static targets = ["methodSelect", "amountInput", "cashSection", "tenderedInput", "changeDisplay"]
  static values = { remaining: Number }

  connect() {
    this.methodChanged()
  }

  methodChanged() {
    const isCash = this.methodSelectTarget.value === "cash"

    if (this.hasCashSectionTarget) {
      if (isCash) {
        this.cashSectionTarget.classList.remove("hidden")
      } else {
        this.cashSectionTarget.classList.add("hidden")
      }
    }
  }

  calculateChange() {
    if (!this.hasTenderedInputTarget || !this.hasChangeDisplayTarget) return

    const amount = parseFloat(this.amountInputTarget.value) || 0
    const tendered = parseFloat(this.tenderedInputTarget.value) || 0
    const change = Math.max(tendered - amount, 0)

    this.changeDisplayTarget.textContent = `$${change.toFixed(2)}`
  }
}
