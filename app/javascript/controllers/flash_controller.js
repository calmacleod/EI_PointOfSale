import { Controller } from "@hotwired/stimulus"

const CIRCLE_CIRCUMFERENCE = 2 * Math.PI * 9

export default class extends Controller {
  static targets = ["circle"]
  static values = {
    duration: { type: Number, default: 5 }
  }

  connect() {
    this.animateCircle()
    this.dismissTimer = setTimeout(() => this.dismiss(), this.durationValue * 1000)
  }

  disconnect() {
    if (this.dismissTimer) clearTimeout(this.dismissTimer)
  }

  animateCircle() {
    this.circleTargets.forEach((circle) => {
      circle.style.strokeDasharray = CIRCLE_CIRCUMFERENCE
      circle.style.strokeDashoffset = 0
      circle.style.transition = `stroke-dashoffset ${this.durationValue}s linear`

      requestAnimationFrame(() => {
        circle.style.strokeDashoffset = CIRCLE_CIRCUMFERENCE
      })
    })
  }

  dismiss() {
    this.element.style.transition = "opacity 0.2s ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 200)
  }
}
