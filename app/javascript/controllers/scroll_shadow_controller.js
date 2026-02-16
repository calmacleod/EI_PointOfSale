import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scroller"]

  scrollerTargetConnected(scroller) {
    this.update = this.update.bind(this)
    scroller.addEventListener("scroll", this.update, { passive: true })
    this.resizeObserver = new ResizeObserver(this.update)
    this.resizeObserver.observe(scroller)

    requestAnimationFrame(this.update)
  }

  scrollerTargetDisconnected(scroller) {
    scroller.removeEventListener("scroll", this.update)
    this.resizeObserver?.disconnect()
  }

  update() {
    if (!this.hasScrollerTarget) return

    const { scrollLeft, scrollWidth, clientWidth } = this.scrollerTarget
    const atStart = scrollLeft <= 1
    const atEnd = scrollLeft + clientWidth >= scrollWidth - 1

    this.element.classList.toggle("shadow-scroll-left", !atStart)
    this.element.classList.toggle("shadow-scroll-right", !atEnd)
  }
}
