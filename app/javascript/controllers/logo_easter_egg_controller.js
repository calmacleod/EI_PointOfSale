import { Controller } from "@hotwired/stimulus"

const CLICK_WINDOW_MS = 500
const REQUIRED_CLICKS = 3

export default class extends Controller {
  connect() {
    this.clickTimes = []
  }

  click(event) {
    if (event.type === "keydown" && event.key !== "Enter" && event.key !== " ") return
    if (event.type === "keydown") event.preventDefault()

    this.clickTimes.push(Date.now())

    // Keep only clicks within the time window
    const now = Date.now()
    this.clickTimes = this.clickTimes.filter((t) => now - t < CLICK_WINDOW_MS)

    if (this.clickTimes.length >= REQUIRED_CLICKS) {
      this.triggerEasterEgg()
      this.clickTimes = []
    }
  }

  triggerEasterEgg() {
    if (this.isAnimating) return

    this.isAnimating = true
    this.element.classList.add("logo-easter-egg-active")

    // Remove animation class after it finishes so it can be retriggered
    const duration = 2000
    setTimeout(() => {
      this.element.classList.remove("logo-easter-egg-active")
      this.isAnimating = false
    }, duration)
  }
}
