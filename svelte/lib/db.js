const DB_NAME = "ei_pos_offline"
const DB_VERSION = 1

export function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION)

    req.onupgradeneeded = (event) => {
      const db = event.target.result
      if (!db.objectStoreNames.contains("products")) {
        const store = db.createObjectStore("products", { keyPath: "id" })
        store.createIndex("code", "code", { unique: true })
        store.createIndex("name", "name", { unique: false })
      }
      if (!db.objectStoreNames.contains("meta")) {
        db.createObjectStore("meta", { keyPath: "key" })
      }
    }

    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

export function idbGet(source, key) {
  return new Promise((resolve, reject) => {
    const req = source.get(key)
    req.onsuccess = () => resolve(req.result ?? null)
    req.onerror = () => reject(req.error)
  })
}

export function idbGetAll(store) {
  return new Promise((resolve, reject) => {
    const req = store.getAll()
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

export function txComplete(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = resolve
    tx.onerror = () => reject(tx.error)
  })
}
