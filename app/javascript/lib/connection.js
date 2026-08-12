const FAKE_OFFLINE_KEY = "ei_pos_fake_offline"

export function browserOnline() {
  if (typeof navigator === "undefined") return true

  return navigator.onLine && readStorageValue(FAKE_OFFLINE_KEY) !== "true"
}

export async function connectionAvailable() {
  if (!browserOnline()) return false

  try {
    const response = await fetch("/up", {
      method: "HEAD",
      cache: "no-store",
      credentials: "same-origin",
    })

    return response.ok
  } catch (_error) {
    return false
  }
}

function readStorageValue(key) {
  try {
    return window.localStorage.getItem(key)
  } catch (_error) {
    return null
  }
}
