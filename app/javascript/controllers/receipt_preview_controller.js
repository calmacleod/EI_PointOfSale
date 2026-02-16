import { Controller } from "@hotwired/stimulus"

// Renders a live thermal receipt preview as the user toggles options
// and edits text fields in the receipt template form.
export default class extends Controller {
  static targets = [
    "output", "paper", "paperWidth",
    "showStoreName", "showStoreAddress", "showStorePhone", "showStoreEmail",
    "showLogo", "trimLogo", "logoContainer", "logoImage",
    "showDateTime", "showCashierName",
    "headerText", "footerText"
  ]

  static values = {
    storeName: String,
    storeAddress: String,
    storePhone: String,
    storeEmail: String,
    logoUrl: String,
    trimmedLogoUrl: String
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
      this.storeAddressValue.split("\n").forEach(addrLine => {
        lines.push(...this.centerWrap(addrLine, chars))
      })
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

    // Toggle logo visibility and swap src for trim setting
    if (this.hasLogoContainerTarget) {
      const showLogo = this.isChecked("showLogo") && this.logoUrlValue
      this.logoContainerTarget.classList.toggle("hidden", !showLogo)

      if (showLogo && this.hasLogoImageTarget) {
        const trimmed = this.isChecked("trimLogo")
        const url = trimmed && this.trimmedLogoUrlValue
          ? this.trimmedLogoUrlValue
          : this.logoUrlValue
        if (this.logoImageTarget.src !== url) {
          this.logoImageTarget.src = url
        }
      }
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

    const words = text.split(/\s+/)
    const lines = []
    let currentLine = ""

    for (const word of words) {
      if (word.length > width) {
        if (currentLine) {
          lines.push(this.center(currentLine, width))
          currentLine = ""
        }
        for (let i = 0; i < word.length; i += width) {
          lines.push(this.center(word.slice(i, i + width), width))
        }
      } else if (currentLine === "") {
        currentLine = word
      } else if (currentLine.length + 1 + word.length <= width) {
        currentLine += " " + word
      } else {
        lines.push(this.center(currentLine, width))
        currentLine = word
      }
    }

    if (currentLine) lines.push(this.center(currentLine, width))
    return lines.length > 0 ? lines : [" ".repeat(width)]
  }

  leftRight(left, right, width) {
    const gap = Math.max(1, width - left.length - right.length)
    return left + " ".repeat(gap) + right
  }

  separator(width) {
    return "=".repeat(width)
  }
}
