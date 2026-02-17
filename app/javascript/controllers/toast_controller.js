import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 },
    url: String
  }

  connect() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(100%)"
    this.element.style.transition = "opacity 300ms ease, transform 300ms ease"
    
    requestAnimationFrame(() => {
      this.element.style.opacity = "1"
      this.element.style.transform = "translateX(0)"
    })

    this.dismissTimeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }
  }

  dismiss() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(100%)"
    setTimeout(() => this.element.remove(), 300)
  }

  handleClick(event) {
    if (event.target.closest("button")) return
    
    if (this.hasUrlValue) {
      window.Turbo?.visit(this.urlValue)
    }
  }
}
