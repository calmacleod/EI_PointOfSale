import { Controller } from "@hotwired/stimulus"

// Handles live denomination counting on the cash drawer open/close forms.
// Each input carries a `data-value` attribute with the denomination's value in cents.
// As counts change, subtotals and the grand total are recalculated instantly.
export default class extends Controller {
  static targets = ["input", "subtotal", "grandTotal"]

  connect() {
    this.calculate()
  }

  calculate() {
    let grandTotalCents = 0

    this.inputTargets.forEach((input, index) => {
      const count = Math.max(0, parseInt(input.value, 10) || 0)
      const valueCents = parseInt(input.dataset.value, 10) || 0
      const subtotalCents = count * valueCents

      if (this.subtotalTargets[index]) {
        this.subtotalTargets[index].textContent = this.formatCurrency(subtotalCents)
      }

      grandTotalCents += subtotalCents
    })

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.formatCurrency(grandTotalCents)
    }
  }

  formatCurrency(cents) {
    const dollars = cents / 100
    return new Intl.NumberFormat("en-CA", {
      style: "currency",
      currency: "CAD",
      minimumFractionDigits: 2
    }).format(dollars)
  }
}
