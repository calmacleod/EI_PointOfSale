import { Controller } from "@hotwired/stimulus"

// Opens a fullscreen overlay to view images at full size.
// Supports prev/next navigation and keyboard shortcuts.
// The lightbox overlay is a global singleton element rendered in the layout.
//
// Usage:
//   <div data-controller="image-lightbox" data-image-lightbox-urls-value="[...]">
//     <img data-action="click->image-lightbox#open"
//          data-image-lightbox-index-param="0"
//          data-image-lightbox-url-param="https://..." />
//   </div>
export default class extends Controller {
  static values = { urls: Array }

  connect() {
    this.currentIndex = 0
    this.boundKeydown = this.handleKeydown.bind(this)

    // Find the global lightbox overlay
    this.overlay = document.querySelector('[data-lightbox-overlay]')
    this.image = document.querySelector('[data-lightbox-image]')
    this.counter = document.querySelector('[data-lightbox-counter]')
    this.prevButton = document.querySelector('[data-lightbox-prev]')
    this.nextButton = document.querySelector('[data-lightbox-next]')
    this.closeButton = document.querySelector('[data-lightbox-close]')

    // Bind button actions if found
    if (this.closeButton) {
      this.closeButton.onclick = (e) => {
        e.stopPropagation()
        this.close()
      }
    }
    if (this.prevButton) {
      this.prevButton.onclick = (e) => {
        e.stopPropagation()
        this.prev()
      }
    }
    if (this.nextButton) {
      this.nextButton.onclick = (e) => {
        e.stopPropagation()
        this.next()
      }
    }
    if (this.overlay) {
      this.overlay.onclick = (e) => {
        if (e.target === this.overlay || e.target === this.image) {
          this.close()
        }
      }
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open({ params: { index, url } }) {
    this.currentIndex = index || 0

    if (!this.overlay || !this.image) {
      console.error("Lightbox overlay not found")
      return
    }

    // Show/hide navigation based on number of images
    const hasMultipleImages = this.urlsValue.length > 1
    if (this.prevButton) {
      this.prevButton.classList.toggle("hidden", !hasMultipleImages)
    }
    if (this.nextButton) {
      this.nextButton.classList.toggle("hidden", !hasMultipleImages)
    }

    this.show(url || this.urlsValue[this.currentIndex])
  }

  close() {
    if (this.overlay) {
      this.overlay.classList.add("hidden")
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
    if (this.image) {
      this.image.src = url
    }
    if (this.overlay) {
      this.overlay.classList.remove("hidden")
    }
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.boundKeydown)
    this.updateCounter()
  }

  updateCounter() {
    if (this.counter && this.urlsValue.length > 1) {
      this.counter.textContent = `${this.currentIndex + 1} / ${this.urlsValue.length}`
      this.counter.classList.remove("hidden")
    } else if (this.counter) {
      this.counter.classList.add("hidden")
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
}
