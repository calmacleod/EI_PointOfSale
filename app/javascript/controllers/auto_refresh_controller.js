import { Controller } from "@hotwired/stimulus"

// Automatically refreshes the current page at a set interval.
// Used on report show pages while the report is still processing.
//
// Usage:
//   <div data-controller="auto-refresh" data-auto-refresh-interval-value="3000">
//
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.timer = setInterval(() => {
      Turbo.visit(window.location.href, { action: "replace" })
    }, this.intervalValue)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
