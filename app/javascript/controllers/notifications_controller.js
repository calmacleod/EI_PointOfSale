import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const TOAST_DURATION = 5000

export default class extends Controller {
  static targets = ["badge", "toastContainer"]
  static values = { userId: Number }

  connect() {
    this.consumer = createConsumer()
    this.channel = this.consumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: (data) => this.handleNotification(data) }
    )
    this.dropdownOpen = false
  }

  disconnect() {
    this.channel?.unsubscribe()
    this.consumer?.disconnect()
    this.closePopover()
  }

  handleNotification(data) {
    this.showToast(data)

    if (data.persistent && this.hasBadgeTarget) {
      this.incrementBadge()
    }
  }

  showToast(data) {
    if (!this.hasToastContainerTarget) return

    const toast = document.createElement("div")
    toast.className = "notification-toast"
    toast.innerHTML = `
      <div class="flex items-start gap-2.5 rounded-lg border border-theme bg-surface px-3 py-2.5 shadow-lg" style="min-width: 280px; max-width: 360px;">
        <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-accent/10 text-accent">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
          </svg>
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-body">${this.escapeHtml(data.title)}</p>
          ${data.body ? `<p class="mt-0.5 text-xs text-muted line-clamp-2">${this.escapeHtml(data.body)}</p>` : ""}
        </div>
        <button type="button" class="shrink-0 text-muted hover:text-body" data-action="click->notifications#dismissToast">
          <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `

    if (data.url) {
      toast.style.cursor = "pointer"
      toast.addEventListener("click", (e) => {
        if (e.target.closest("button")) return
        window.Turbo?.visit(data.url)
      })
    }

    toast.style.opacity = "0"
    toast.style.transform = "translateX(100%)"
    toast.style.transition = "opacity 300ms ease, transform 300ms ease"
    this.toastContainerTarget.appendChild(toast)

    requestAnimationFrame(() => {
      toast.style.opacity = "1"
      toast.style.transform = "translateX(0)"
    })

    setTimeout(() => this.removeToast(toast), TOAST_DURATION)
  }

  dismissToast(event) {
    const toast = event.target.closest(".notification-toast")
    if (toast) this.removeToast(toast)
  }

  removeToast(toast) {
    toast.style.opacity = "0"
    toast.style.transform = "translateX(100%)"
    setTimeout(() => toast.remove(), 300)
  }

  incrementBadge() {
    if (!this.hasBadgeTarget) return
    const badge = this.badgeTarget
    const current = parseInt(badge.textContent, 10) || 0
    badge.textContent = String(current + 1)
    badge.classList.remove("hidden")
  }

  toggleDropdown(event) {
    const button = event.currentTarget

    if (this.activePopover) {
      this.closePopover()
      return
    }

    const popover = document.createElement("div")
    popover.style.position = "fixed"
    popover.style.zIndex = "9999"
    popover.innerHTML = `<turbo-frame id="notifications_popover" src="/notifications" loading="eager"></turbo-frame>`

    const rect = button.getBoundingClientRect()
    const isSidebar = button.closest("aside") !== null

    if (isSidebar) {
      popover.style.left = `${rect.right + 8}px`
      popover.style.bottom = `${window.innerHeight - rect.bottom}px`
    } else {
      popover.style.right = `${window.innerWidth - rect.right}px`
      popover.style.top = `${rect.bottom + 4}px`
    }

    document.body.appendChild(popover)
    this.activePopover = popover

    popover.addEventListener("click", (e) => {
      const target = e.target.closest("[data-action]")
      if (!target) return

      const action = target.dataset.action
      if (action?.includes("markAllReadAndRefresh")) {
        e.preventDefault()
        this.markAllReadAndRefresh()
      } else if (action?.includes("clearAllNotifications")) {
        e.preventDefault()
        this.clearAllNotifications()
      } else if (action?.includes("dismissNotification")) {
        e.preventDefault()
        e.stopPropagation()
        const id = target.dataset.notificationId
        if (id) this.dismissNotificationById(id)
      } else if (action?.includes("markRead")) {
        const id = target.dataset.notificationId
        if (id) this.markReadById(id)
      }
    })

    this.boundCloseOnClickOutside = (e) => {
      if (!popover.contains(e.target) && !button.contains(e.target)) {
        this.closePopover()
      }
    }
    setTimeout(() => document.addEventListener("click", this.boundCloseOnClickOutside), 0)
  }

  closePopover() {
    if (this.activePopover) {
      this.activePopover.remove()
      this.activePopover = null
    }
    if (this.boundCloseOnClickOutside) {
      document.removeEventListener("click", this.boundCloseOnClickOutside)
      this.boundCloseOnClickOutside = null
    }
  }

  markRead(event) {
    const id = event.currentTarget?.dataset?.notificationId
    if (id) this.markReadById(id)
  }

  markReadById(id) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/notifications/${id}/mark_read`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).catch(() => {})
  }

  markAllReadAndRefresh() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/notifications/mark_all_read", {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => {
      this.badgeTargets.forEach((badge) => {
        badge.textContent = "0"
        badge.classList.add("hidden")
      })

      if (this.activePopover) {
        const frame = this.activePopover.querySelector("turbo-frame")
        if (frame) frame.src = "/notifications"
      }
    }).catch(() => {})
  }

  dismissNotification(event) {
    event.preventDefault()
    event.stopPropagation()
    const id = event.currentTarget?.dataset?.notificationId
    if (id) this.dismissNotificationById(id)
  }

  dismissNotificationById(id) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/notifications/${id}`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => this.refreshPopover()).catch(() => {})
  }

  clearAllNotifications() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/notifications/clear_all", {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json" },
      credentials: "same-origin"
    }).then(() => {
      this.badgeTargets.forEach((badge) => {
        badge.textContent = "0"
        badge.classList.add("hidden")
      })
      this.refreshPopover()
    }).catch(() => {})
  }

  refreshPopover() {
    if (this.activePopover) {
      const frame = this.activePopover.querySelector("turbo-frame")
      if (frame) frame.src = "/notifications"
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
