import { Controller } from "@hotwired/stimulus"

// Renders a live thermal receipt preview as the user toggles options
// and edits text fields in the receipt template form.
export default class extends Controller {
  static targets = [
    "output", "paper", "paperWidth",
    "showStoreName", "showStoreAddress", "showStorePhone", "showStoreEmail",
    "showDateTime", "showCashierName",
    "headerText", "footerText"
  ]

  static values = {
    storeName: String,
    storeAddress: String,
    storePhone: String,
    storeEmail: String
  }

  connect() {
    this.update()
  }

  update() {
    const width = this.currentWidth()
    const chars = width === 58 ? 32 : 48
    const lines = []

    // Store info
    if (this.isChecked("showStoreName") && this.storeNameValue) {
      lines.push(...this.centerWrap(this.storeNameValue.toUpperCase(), chars))
    }
    if (this.isChecked("showStoreAddress") && this.storeAddressValue) {
      lines.push(...this.centerWrap(this.storeAddressValue, chars))
    }
    if (this.isChecked("showStorePhone") && this.storePhoneValue) {
      lines.push(this.center(`Tel: ${this.storePhoneValue}`, chars))
    }
    if (this.isChecked("showStoreEmail") && this.storeEmailValue) {
      lines.push(this.center(this.storeEmailValue, chars))
    }

    if (lines.length > 0) lines.push(this.separator(chars))

    // Header text
    const headerText = this.getTextValue("headerText")
    if (headerText) {
      headerText.split("\n").forEach(line => {
        lines.push(...this.centerWrap(line, chars))
      })
      lines.push(this.separator(chars))
    }

    // Date/time and cashier
    if (this.isChecked("showDateTime")) {
      const now = new Date()
      const dateStr = now.toISOString().slice(0, 10)
      const timeStr = now.toTimeString().slice(0, 5)
      lines.push(this.leftRight(`Date: ${dateStr}`, timeStr, chars))
    }
    if (this.isChecked("showCashierName")) {
      lines.push(this.leftRight("Cashier:", "Staff Name", chars))
    }
    if (this.isChecked("showDateTime") || this.isChecked("showCashierName")) {
      lines.push(this.separator(chars))
    }

    // Order placeholder
    lines.push("")
    lines.push(this.center("[ Order items will appear here ]", chars))
    lines.push("")
    lines.push(this.separator(chars))

    // Totals
    lines.push(this.leftRight("Subtotal:", "$0.00", chars))
    lines.push(this.leftRight("Tax:", "$0.00", chars))
    lines.push(this.leftRight("TOTAL:", "$0.00", chars))
    lines.push(this.separator(chars))

    // Footer text
    const footerText = this.getTextValue("footerText")
    if (footerText) {
      lines.push("")
      footerText.split("\n").forEach(line => {
        lines.push(...this.centerWrap(line, chars))
      })
    }

    // Update the preview
    if (this.hasOutputTarget) {
      this.outputTarget.textContent = lines.join("\n")
      this.outputTarget.style.fontSize = "11px"
      this.outputTarget.style.width = `${chars}ch`
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  currentWidth() {
    if (this.hasPaperWidthTarget) {
      return parseInt(this.paperWidthTarget.value, 10) || 80
    }
    return 80
  }

  isChecked(targetName) {
    const target = this[`has${this.capitalize(targetName)}Target`]
      ? this[`${targetName}Target`]
      : null
    if (!target) return true
    return target.checked
  }

  getTextValue(targetName) {
    const target = this[`has${this.capitalize(targetName)}Target`]
      ? this[`${targetName}Target`]
      : null
    if (!target) return ""
    return target.value.trim()
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }

  center(text, width) {
    if (text.length >= width) return text.slice(0, width)
    const pad = Math.floor((width - text.length) / 2)
    return " ".repeat(pad) + text + " ".repeat(width - pad - text.length)
  }

  centerWrap(text, width) {
    if (!text || text.length === 0) return [" ".repeat(width)]
    const lines = []
    for (let i = 0; i < text.length; i += width) {
      const chunk = text.slice(i, i + width)
      lines.push(this.center(chunk, width))
    }
    return lines
  }

  leftRight(left, right, width) {
    const gap = Math.max(1, width - left.length - right.length)
    return left + " ".repeat(gap) + right
  }

  separator(width) {
    return "=".repeat(width)
  }
}
