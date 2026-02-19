import { Controller } from "@hotwired/stimulus"

// Manages the payment form: shows cash-specific fields, calculates change,
// and looks up gift certificate balances.
export default class extends Controller {
  static targets = [
    "methodInput", "methodButton", "amountInput", "cashSection", "tenderedInput", "changeDisplay",
    "gcBalanceDisplay", "gcBalanceAmount", "gcNotFound", "referenceInput",
    "adjustModal", "adjustModalMessage"
  ]
  static values = { remaining: Number, gcLookupUrl: String }

  // Store pending submit event for modal confirmation
  #pendingSubmitEvent = null

  connect() {
    this.#updateMethodUI(this.methodInputTarget.value, { applyRounding: true })
  }

  selectMethod(event) {
    const method = event.currentTarget.dataset.method
    const previousMethod = this.methodInputTarget.value
    this.methodInputTarget.value = method
    this.#updateMethodUI(method, { previousMethod: previousMethod })
  }

  #updateMethodUI(method, options = {}) {
    const isCash = method === "cash"
    const isGc   = method === "gift_certificate"
    const wasCash = options.previousMethod === "cash"

    // Update button styles
    if (this.hasMethodButtonTarget) {
      this.methodButtonTargets.forEach(btn => {
        const isActive = btn.dataset.method === method
        btn.classList.toggle("bg-accent", isActive)
        btn.classList.toggle("text-white", isActive)
        btn.classList.toggle("border-accent", isActive)
        btn.classList.toggle("bg-surface", !isActive)
        btn.classList.toggle("text-muted", !isActive)
        btn.classList.toggle("border-theme", !isActive)
      })
    }

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

    // Only apply rounding when actually switching to/from cash, not on every update
    // On initial connect, apply rounding if cash is selected
    if (options.applyRounding && isCash) {
      this.#roundAmountForCash()
    } else if (options.previousMethod) {
      // Switching payment methods
      if (!wasCash && isCash) {
        // Switching TO cash - apply rounding
        this.#roundAmountForCash()
      } else if (wasCash && !isCash) {
        // Switching FROM cash - restore unrounded amount
        this.#unroundAmountForNonCash()
      }
      // If switching between two non-cash methods, don't touch the amount
    }
  }

  onReferenceInput() {
    if (this.methodInputTarget.value !== "gift_certificate") return

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

  validateBeforeSubmit(event) {
    // Only check for cash payments
    if (this.methodInputTarget.value !== "cash") return

    // Only check if cash section is visible and tendered input has a value
    if (!this.hasTenderedInputTarget) return

    const amount = parseFloat(this.amountInputTarget.value) || 0
    const tendered = parseFloat(this.tenderedInputTarget.value) || 0

    // If tendered is less than amount, show modal to ask user if they want to lower the payment
    if (tendered > 0 && tendered < amount) {
      event.preventDefault()
      this.#pendingSubmitEvent = event

      // Update modal message
      if (this.hasAdjustModalMessageTarget) {
        this.adjustModalMessageTarget.textContent =
          `Amount tendered ($${tendered.toFixed(2)}) is less than the payment amount ($${amount.toFixed(2)}). ` +
          `Do you want to lower the payment to $${tendered.toFixed(2)}?`
      }

      // Show the modal
      if (this.hasAdjustModalTarget) {
        this.adjustModalTarget.classList.remove("hidden")
      }
    }
  }

  closeAdjustModal() {
    if (this.hasAdjustModalTarget) {
      this.adjustModalTarget.classList.add("hidden")
    }
    this.#pendingSubmitEvent = null
  }

  confirmAdjustAmount() {
    if (!this.#pendingSubmitEvent) return

    const tendered = parseFloat(this.tenderedInputTarget.value) || 0

    // Lower the payment amount to match what was tendered
    this.amountInputTarget.value = tendered.toFixed(2)

    // Recalculate change (should be 0 now)
    this.calculateChange()

    // Hide modal
    if (this.hasAdjustModalTarget) {
      this.adjustModalTarget.classList.add("hidden")
    }

    // Submit the form
    this.#pendingSubmitEvent.target.requestSubmit()
    this.#pendingSubmitEvent = null
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
