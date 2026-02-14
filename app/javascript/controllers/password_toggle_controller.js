import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggle", "showIcon", "hideIcon"]

  connect() {
    this.updateIcons()
  }

  toggleVisibility(event) {
    event.preventDefault()
    this.inputTarget.type = this.inputTarget.type === "password" ? "text" : "password"
    this.updateIcons()
  }

  updateIcons() {
    const isHidden = this.inputTarget.type === "password"
    this.showIconTarget?.classList.toggle("hidden", !isHidden)
    this.hideIconTarget?.classList.toggle("hidden", isHidden)
    this.toggleTarget?.setAttribute("aria-label", isHidden ? "Show password" : "Hide password")
  }
}
