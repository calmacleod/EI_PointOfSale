import { Controller } from "@hotwired/stimulus"

// Opens a fullscreen overlay to view images at full size.
// Supports prev/next navigation and keyboard shortcuts.
//
// Usage:
//   <div data-controller="image-lightbox">
//     <img data-action="click->image-lightbox#open"
//          data-image-lightbox-index-param="0"
//          data-image-lightbox-url-param="https://..." />
//   </div>
export default class extends Controller {
  static targets = ["overlay", "image", "counter"]
  static values = { urls: Array }

  connect() {
    this.currentIndex = 0
    this.boundKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open({ params: { index, url } }) {
    this.currentIndex = index || 0

    if (!this.hasOverlayTarget) {
      this.buildOverlay()
    }

    this.show(url || this.urlsValue[this.currentIndex])
  }

  close() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  next(event) {
    if (event) event.stopPropagation()
    if (this.urlsValue.length === 0) return
    this.currentIndex = (this.currentIndex + 1) % this.urlsValue.length
    this.show(this.urlsValue[this.currentIndex])
  }

  prev(event) {
    if (event) event.stopPropagation()
    if (this.urlsValue.length === 0) return
    this.currentIndex = (this.currentIndex - 1 + this.urlsValue.length) % this.urlsValue.length
    this.show(this.urlsValue[this.currentIndex])
  }

  // ── Private ──────────────────────────────────────────────────────

  show(url) {
    this.imageTarget.src = url
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundKeydown)
    this.updateCounter()
  }

  updateCounter() {
    if (this.hasCounterTarget && this.urlsValue.length > 1) {
      this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.urlsValue.length}`
      this.counterTarget.classList.remove("hidden")
    }
  }

  handleKeydown(event) {
    switch (event.key) {
      case "Escape":
        this.close()
        break
      case "ArrowRight":
        this.next()
        break
      case "ArrowLeft":
        this.prev()
        break
    }
  }

  buildOverlay() {
    const overlay = document.createElement("div")
    overlay.dataset.imageLightboxTarget = "overlay"
    overlay.className = "fixed inset-0 z-[70] hidden flex items-center justify-center bg-black/80 backdrop-blur-sm"
    overlay.dataset.action = "click->image-lightbox#close"

    overlay.innerHTML = `
      <button data-action="click->image-lightbox#close"
              class="absolute top-4 right-4 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
              aria-label="Close">
        <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>

      ${this.urlsValue.length > 1 ? `
        <button data-action="click->image-lightbox#prev"
                class="absolute left-4 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
                aria-label="Previous image">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
        </button>
        <button data-action="click->image-lightbox#next"
                class="absolute right-4 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
                aria-label="Next image">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </button>
      ` : ""}

      <img data-image-lightbox-target="image"
           data-action="click->image-lightbox#stopPropagation"
           class="max-h-[90vh] max-w-[90vw] rounded-lg object-contain shadow-2xl"
           alt="Enlarged image" />

      <span data-image-lightbox-target="counter"
            class="absolute bottom-4 left-1/2 -translate-x-1/2 rounded-full bg-black/50 px-3 py-1 text-sm text-white hidden">
      </span>
    `

    this.element.appendChild(overlay)
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
