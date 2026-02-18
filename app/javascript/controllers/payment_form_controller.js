import { Controller } from "@hotwired/stimulus"

// Manages the payment form: shows cash-specific fields, calculates change,
// and looks up gift certificate balances.
export default class extends Controller {
  static targets = [
    "methodSelect", "amountInput", "cashSection", "tenderedInput", "changeDisplay",
    "gcBalanceDisplay", "gcBalanceAmount", "gcNotFound", "referenceInput"
  ]
  static values = { remaining: Number, gcLookupUrl: String }

  connect() {
    this.methodChanged()
  }

  methodChanged() {
    const method = this.methodSelectTarget.value
    const isCash = method === "cash"
    const isGc   = method === "gift_certificate"

    if (this.hasCashSectionTarget) {
      this.cashSectionTarget.classList.toggle("hidden", !isCash)
    }

    if (this.hasReferenceInputTarget) {
      if (isGc) {
        this.referenceInputTarget.placeholder = "Gift certificate code (e.g. GC-XXXXXXXX)"
        this.referenceInputTarget.classList.add("font-mono", "uppercase")
      } else {
        this.referenceInputTarget.placeholder = "Reference (optional)"
        this.referenceInputTarget.classList.remove("font-mono", "uppercase")
        this.#hideGcFeedback()
      }
    }

    if (isCash) {
      this.#roundAmountForCash()
    } else {
      this.#unroundAmountForNonCash()
    }
  }

  onReferenceInput() {
    if (this.methodSelectTarget.value !== "gift_certificate") return

    const code = this.referenceInputTarget.value.trim().toUpperCase()
    if (code.length >= 3) {
      this.#lookupGiftCertificate(code)
    } else {
      this.#hideGcFeedback()
    }
  }

  calculateChange() {
    if (!this.hasTenderedInputTarget || !this.hasChangeDisplayTarget) return

    const amount = parseFloat(this.amountInputTarget.value) || 0
    const tendered = parseFloat(this.tenderedInputTarget.value) || 0
    const change = Math.max(tendered - amount, 0)

    this.changeDisplayTarget.textContent = `$${change.toFixed(2)}`
  }

  // Private

  async #lookupGiftCertificate(code) {
    if (!this.hasGcLookupUrlValue) return

    try {
      const url = `${this.gcLookupUrlValue}?code=${encodeURIComponent(code)}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      const data = await response.json()

      if (data.found) {
        if (this.hasGcBalanceDisplayTarget) this.gcBalanceDisplayTarget.classList.remove("hidden")
        if (this.hasGcBalanceAmountTarget)  this.gcBalanceAmountTarget.textContent = data.balance_formatted
        if (this.hasGcNotFoundTarget)        this.gcNotFoundTarget.classList.add("hidden")

        // Pre-fill amount with min(gc_balance, order_remaining)
        if (this.hasAmountInputTarget) {
          const suggested = Math.min(data.balance, this.remainingValue)
          this.amountInputTarget.value = suggested.toFixed(2)
        }
      } else {
        if (this.hasGcBalanceDisplayTarget) this.gcBalanceDisplayTarget.classList.add("hidden")
        if (this.hasGcNotFoundTarget)        this.gcNotFoundTarget.classList.remove("hidden")
      }
    } catch {
      this.#hideGcFeedback()
    }
  }

  #hideGcFeedback() {
    if (this.hasGcBalanceDisplayTarget) this.gcBalanceDisplayTarget.classList.add("hidden")
    if (this.hasGcNotFoundTarget)        this.gcNotFoundTarget.classList.add("hidden")
  }

  // Round amount to nearest 5 cents for cash payments (Canadian rounding)
  #roundAmountForCash() {
    if (!this.hasAmountInputTarget) return

    const amount = parseFloat(this.amountInputTarget.value) || 0
    const rounded = Math.round(amount * 20) / 20

    // Store the unrounded amount before rounding
    this.amountInputTarget.dataset.unroundedValue = amount.toFixed(2)
    this.amountInputTarget.value = rounded.toFixed(2)
  }

  // Restore the unrounded amount when switching to non-cash payment
  #unroundAmountForNonCash() {
    if (!this.hasAmountInputTarget) return

    const unrounded = this.amountInputTarget.dataset.unroundedValue
    if (unrounded) {
      this.amountInputTarget.value = unrounded
      delete this.amountInputTarget.dataset.unroundedValue
    }
  }
}
