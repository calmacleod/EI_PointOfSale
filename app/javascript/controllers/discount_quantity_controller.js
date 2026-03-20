import { Controller } from "@hotwired/stimulus"

// Inline editing of how many units receive a per-line discount.
// Submits a PATCH to update the applied_quantity on the OrderLineDiscount.
export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  handleKey(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    }
  }

  async save() {
    const qty = parseInt(this.inputTarget.value, 10)
    if (isNaN(qty) || qty < 0) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: `order_line_discount[applied_quantity]=${qty}`
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (e) {
      console.error("Failed to update discount quantity:", e)
    }
  }
}
