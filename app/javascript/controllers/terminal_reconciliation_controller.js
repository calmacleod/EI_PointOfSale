import { Controller } from "@hotwired/stimulus"

// Calculates live discrepancies on the terminal reconciliation form.
// Reads expected totals from data attributes and updates discrepancy display as the user types.
export default class extends Controller {
  static targets = [
    "debitInput", "creditInput",
    "debitDiscrepancy", "creditDiscrepancy", "totalDiscrepancy"
  ]
  static values = {
    expectedDebit: Number,
    expectedCredit: Number
  }

  connect() {
    this.calculate()
  }

  calculate() {
    const debit = parseFloat(this.debitInputTarget.value) || 0
    const credit = parseFloat(this.creditInputTarget.value) || 0
    const debitDisc = debit - this.expectedDebitValue
    const creditDisc = credit - this.expectedCreditValue
    const totalDisc = debitDisc + creditDisc

    this.debitDiscrepancyTarget.textContent = this.#formatDiscrepancy(debitDisc)
    this.#applyColor(this.debitDiscrepancyTarget, debitDisc)

    this.creditDiscrepancyTarget.textContent = this.#formatDiscrepancy(creditDisc)
    this.#applyColor(this.creditDiscrepancyTarget, creditDisc)

    this.totalDiscrepancyTarget.textContent = this.#formatDiscrepancy(totalDisc)
    this.#applyColor(this.totalDiscrepancyTarget, totalDisc)
  }

  #formatDiscrepancy(amount) {
    const prefix = amount >= 0 ? "+" : ""
    return prefix + new Intl.NumberFormat("en-CA", {
      style: "currency",
      currency: "CAD",
      minimumFractionDigits: 2
    }).format(amount)
  }

  #applyColor(el, amount) {
    el.classList.remove("text-green-600", "dark:text-green-400", "text-red-600", "dark:text-red-400", "text-body")
    if (amount > 0) {
      el.classList.add("text-green-600", "dark:text-green-400")
    } else if (amount < 0) {
      el.classList.add("text-red-600", "dark:text-red-400")
    } else {
      el.classList.add("text-body")
    }
  }
}
