const DB_NAME = "ei_pos_offline"
const DB_VERSION = 3

export function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION)

    req.onupgradeneeded = (event) => {
      const db = event.target.result
      if (!db.objectStoreNames.contains("products")) {
        const store = db.createObjectStore("products", { keyPath: "id" })
        store.createIndex("code", "code", { unique: true })
        store.createIndex("name", "name", { unique: false })
        store.createIndex("sales_count", "sales_count", { unique: false })
      } else {
        // v1 → v2: add sales_count index
        const store = event.target.transaction.objectStore("products")
        if (!store.indexNames.contains("sales_count")) {
          store.createIndex("sales_count", "sales_count", { unique: false })
        }
      }
      if (!db.objectStoreNames.contains("meta")) {
        db.createObjectStore("meta", { keyPath: "key" })
      }
      // v3: services, tax_codes, customers
      if (!db.objectStoreNames.contains("services")) {
        const store = db.createObjectStore("services", { keyPath: "id" })
        store.createIndex("code", "code", { unique: false })
        store.createIndex("name", "name", { unique: false })
      }
      if (!db.objectStoreNames.contains("tax_codes")) {
        const store = db.createObjectStore("tax_codes", { keyPath: "id" })
        store.createIndex("code", "code", { unique: true })
      }
      if (!db.objectStoreNames.contains("customers")) {
        const store = db.createObjectStore("customers", { keyPath: "id" })
        store.createIndex("name", "name", { unique: false })
        store.createIndex("member_number", "member_number", { unique: false })
        store.createIndex("email", "email", { unique: false })
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
