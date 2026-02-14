import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 150

export default class extends Controller {
  static targets = ["modal", "input", "results", "form"]
  static values = {
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    this.boundClickOutside = this.handleClickOutside.bind(this)
    this.debounceTimer = null
    this.selectedIndex = -1

    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    document.removeEventListener("click", this.boundClickOutside)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  scheduleSearch() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submitSearch(), DEBOUNCE_MS)
  }

  submitSearch() {
    const q = this.inputTarget?.value?.trim() ?? ""
    if (q.length < this.minLengthValue && this.hasFormTarget) {
      this.renderPlaceholder()
      return
    }
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  onResultsLoaded() {
    this.selectedIndex = -1
    this.updateSelection()
  }

  renderPlaceholder() {
    if (!this.hasResultsTarget) return
    this.resultsTarget.innerHTML =
      '<p class="px-4 py-8 text-center text-sm text-muted">Type to search products, services, users, and more…</p>'
  }

  handleKeydown(event) {
    if (event.key === "/" && !this.isTextInputFocused()) {
      event.preventDefault()
      this.open()
      return
    }

    if (!this.isOpen()) return

    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.close()
        break
      case "ArrowDown":
        event.preventDefault()
        this.selectNext()
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectPrev()
        break
      case "Enter":
        event.preventDefault()
        this.submitSelected()
        break
    }
  }

  handleClickOutside(event) {
    if (!this.modalTarget.contains(event.target)) {
      this.close()
    }
  }

  isTextInputFocused() {
    const active = document.activeElement
    if (!active) return false
    const tag = active.tagName?.toLowerCase()
    const role = active.getAttribute?.("role")
    const editable = active.isContentEditable
    return (
      tag === "input" ||
      tag === "textarea" ||
      tag === "select" ||
      role === "textbox" ||
      role === "searchbox" ||
      editable === true
    )
  }

  isOpen() {
    return this.modalTarget && !this.modalTarget.classList.contains("hidden")
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("click", this.boundClickOutside)
    this.selectedIndex = -1
    this.renderPlaceholder()
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("click", this.boundClickOutside)
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }

  selectNext() {
    const links = this.resultLinks()
    if (links.length === 0) return
    this.selectedIndex = Math.min(this.selectedIndex + 1, links.length - 1)
    this.updateSelection()
  }

  selectPrev() {
    const links = this.resultLinks()
    if (links.length === 0) return
    this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
    this.updateSelection()
  }

  resultLinks() {
    return this.hasResultsTarget ? [...this.resultsTarget.querySelectorAll(".search-result-item")] : []
  }

  updateSelection() {
    const links = this.resultLinks()
    links.forEach((el, i) => {
      el.classList.toggle("bg-[var(--color-border)]/50", i === this.selectedIndex)
      el.classList.toggle("hover:bg-[var(--color-border)]/30", i !== this.selectedIndex)
    })
  }

  submitSelected() {
    const links = this.resultLinks()
    if (this.selectedIndex >= 0 && links[this.selectedIndex]) {
      links[this.selectedIndex].click()
    }
  }
}
