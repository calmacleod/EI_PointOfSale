import { Controller } from "@hotwired/stimulus"

// Inline quantity editing for order line items.
// Click the quantity badge to edit, Enter/Tab to confirm, Escape to cancel.
export default class extends Controller {
  static targets = ["display", "input"]
  static values = { url: String }

  edit() {
    this.displayTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.select()
    this.inputTarget.focus()
  }

  async handleKey(event) {
    if (event.key === "Enter" || event.key === "Tab") {
      event.preventDefault()
      await this.save()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  cancel() {
    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
    this.inputTarget.value = this.displayTarget.textContent.trim()
  }

  async save() {
    const newQty = parseInt(this.inputTarget.value, 10)
    if (isNaN(newQty) || newQty < 1) {
      this.cancel()
      return
    }

    const currentQty = parseInt(this.displayTarget.textContent.trim(), 10)
    if (newQty === currentQty) {
      this.cancel()
      return
    }

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: `order_line[quantity]=${newQty}`
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (e) {
      console.error("Failed to update quantity:", e)
      this.cancel()
    }
  }
}
