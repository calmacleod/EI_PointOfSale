import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "status"]
  static values = { vapidPublicKey: String }

  async connect() {
    this.updateUI()
  }

  async togglePush() {
    if (!("Notification" in window) || !("serviceWorker" in navigator)) {
      this.setStatus("Push notifications are not supported in this browser.")
      return
    }

    const permission = Notification.permission

    if (permission === "denied") {
      this.setStatus("Notifications are blocked. Please enable them in your browser settings.")
      return
    }

    const registration = await navigator.serviceWorker.ready
    const existing = await registration.pushManager.getSubscription()

    if (existing) {
      await this.unsubscribe(existing)
    } else {
      await this.subscribe(registration)
    }

    this.updateUI()
  }

  async subscribe(registration) {
    try {
      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.setStatus("Permission not granted.")
        return
      }

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      const json = subscription.toJSON()
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch("/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        credentials: "same-origin",
        body: JSON.stringify({
          push_subscription: {
            endpoint: json.endpoint,
            p256dh_key: json.keys.p256dh,
            auth_key: json.keys.auth
          }
        })
      })

      if (response.ok) {
        this.setStatus("Push notifications enabled.")
      } else {
        this.setStatus("Failed to save subscription.")
      }
    } catch (error) {
      this.setStatus("Failed to subscribe: " + error.message)
    }
  }

  async unsubscribe(subscription) {
    const endpoint = subscription.endpoint
    await subscription.unsubscribe()

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    await fetch("/push_subscriptions/" + encodeURIComponent("unsubscribe"), {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      credentials: "same-origin",
      body: JSON.stringify({ endpoint })
    }).catch(() => {})

    this.setStatus("Push notifications disabled.")
  }

  async updateUI() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      if (this.hasToggleTarget) this.toggleTarget.disabled = true
      this.setStatus("Not supported in this browser.")
      return
    }

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()

    if (this.hasToggleTarget) {
      this.toggleTarget.checked = !!subscription
    }
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = atob(base64)
    const outputArray = new Uint8Array(rawData.length)
    for (let i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }
}
