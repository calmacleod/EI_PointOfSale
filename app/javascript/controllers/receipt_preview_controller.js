import { Controller } from "@hotwired/stimulus"

// Default section order — mirrors ReceiptTemplate::SECTIONS
const DEFAULT_SECTIONS = ["logo", "store_name", "store_address", "store_phone", "store_email", "header_text", "date_time", "cashier_name"]

// Renders a live thermal receipt preview as the user toggles options,
// edits text fields, and reorders sections in the receipt template form.
export default class extends Controller {
  static targets = [
    "output", "outputBefore", "paper", "paperWidth",
    "showStoreName", "showStoreAddress", "showStorePhone", "showStoreEmail",
    "showLogo", "trimLogo", "logoContainer", "logoImage",
    "showDateTime", "showCashierName",
    "headerText", "footerText",
    "sectionOrder"
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
    const order = this.currentSectionOrder()
    const showLogo = this.isChecked("showLogo") && this.logoUrlValue

    // Split header sections at the logo position so text before/after the logo
    // can be rendered into separate <pre> elements that sandwich the logo <img>.
    const logoIndex = order.indexOf("logo")
    const beforeLogoSections = logoIndex >= 0 ? order.slice(0, logoIndex) : order
    const afterLogoSections  = logoIndex >= 0 ? order.slice(logoIndex + 1) : []

    const beforeLines = []
    for (const section of beforeLogoSections) {
      beforeLines.push(...this.renderSection(section, chars))
    }

    const afterHeaderLines = []
    for (const section of afterLogoSections) {
      afterHeaderLines.push(...this.renderSection(section, chars))
    }

    // The "after" output gets the post-logo header content + order items + totals + footer.
    // A separator separates the header block from the items only if there was any header content.
    const allHeaderLines = [...beforeLines, ...afterHeaderLines]
    const afterLines = [...afterHeaderLines]

    if (allHeaderLines.length > 0) {
      const lastHeader = allHeaderLines[allHeaderLines.length - 1]
      if (lastHeader !== this.separator(chars)) {
        afterLines.push(this.separator(chars))
      }
    }

    // Order placeholder
    afterLines.push("")
    afterLines.push(this.center("[ Order items will appear here ]", chars))
    afterLines.push("")
    afterLines.push(this.separator(chars))

    // Totals
    afterLines.push(this.leftRight("Subtotal:", "$0.00", chars))
    afterLines.push(this.leftRight("Tax:", "$0.00", chars))
    afterLines.push(this.leftRight("TOTAL:", "$0.00", chars))
    afterLines.push(this.separator(chars))

    // Footer text (always at the bottom)
    const footerText = this.getTextValue("footerText")
    if (footerText) {
      afterLines.push("")
      footerText.split("\n").forEach(line => {
        afterLines.push(...this.centerWrap(line, chars))
      })
    }

    // Update outputBefore (sections before logo)
    if (this.hasOutputBeforeTarget) {
      this.outputBeforeTarget.textContent = beforeLines.join("\n")
      this.outputBeforeTarget.style.fontSize = "11px"
      this.outputBeforeTarget.style.width = `${chars}ch`
    }

    // Update main output (sections after logo + body)
    if (this.hasOutputTarget) {
      this.outputTarget.textContent = afterLines.join("\n")
      this.outputTarget.style.fontSize = "11px"
      this.outputTarget.style.width = `${chars}ch`
    }

    // Toggle logo visibility and swap src for trim setting
    if (this.hasLogoContainerTarget) {
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

  // ── Section renderers ─────────────────────────────────────────────

  renderSection(section, chars) {
    switch (section) {
      case "logo":
        return [] // Rendered as <img> above the preview text, not as text lines

      case "store_name":
        if (this.isChecked("showStoreName") && this.storeNameValue) {
          return this.centerWrap(this.storeNameValue.toUpperCase(), chars)
        }
        return []

      case "store_address":
        if (this.isChecked("showStoreAddress") && this.storeAddressValue) {
          const addrLines = []
          this.storeAddressValue.split("\n").forEach(addrLine => {
            addrLines.push(...this.centerWrap(addrLine, chars))
          })
          return addrLines
        }
        return []

      case "store_phone":
        if (this.isChecked("showStorePhone") && this.storePhoneValue) {
          return [this.center(`Tel: ${this.storePhoneValue}`, chars)]
        }
        return []

      case "store_email":
        if (this.isChecked("showStoreEmail") && this.storeEmailValue) {
          return [this.center(this.storeEmailValue, chars)]
        }
        return []

      case "header_text": {
        const headerText = this.getTextValue("headerText")
        if (headerText) {
          const textLines = []
          headerText.split("\n").forEach(line => {
            textLines.push(...this.centerWrap(line, chars))
          })
          textLines.push(this.separator(chars))
          return textLines
        }
        return []
      }

      case "date_time":
        if (this.isChecked("showDateTime")) {
          const now = new Date()
          const dateStr = now.toISOString().slice(0, 10)
          const timeStr = now.toTimeString().slice(0, 5)
          return [this.leftRight(`Date: ${dateStr}`, timeStr, chars)]
        }
        return []

      case "cashier_name":
        if (this.isChecked("showCashierName")) {
          return [this.leftRight("Cashier:", "Staff Name", chars)]
        }
        return []

      default:
        return []
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  currentSectionOrder() {
    if (this.hasSectionOrderTarget) {
      try {
        const parsed = JSON.parse(this.sectionOrderTarget.value || "[]")
        if (Array.isArray(parsed) && parsed.length > 0) {
          // Ensure any sections missing from the stored order are appended
          const all = new Set(DEFAULT_SECTIONS)
          const stored = parsed.filter(s => all.has(s))
          const missing = DEFAULT_SECTIONS.filter(s => !stored.includes(s))
          return [...stored, ...missing]
        }
      } catch (_e) {
        // Fall through to default
      }
    }
    return DEFAULT_SECTIONS
  }

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
