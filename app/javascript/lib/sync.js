const DB_NAME = "ei_pos_offline"
const DB_VERSION = 2
const SYNC_URL = "/api/v1/products/sync"
const META_KEY = "last_synced_at"

function openDb() {
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
    }

    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

function idbGet(source, key) {
  return new Promise((resolve, reject) => {
    const req = source.get(key)
    req.onsuccess = () => resolve(req.result ?? null)
    req.onerror = () => reject(req.error)
  })
}

function idbGetAll(store) {
  return new Promise((resolve, reject) => {
    const req = store.getAll()
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

function txComplete(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = resolve
    tx.onerror = () => reject(tx.error)
  })
}

export async function fullSyncProducts() {
  const db = await openDb()

  const wipeTx = db.transaction(["products", "meta"], "readwrite")
  wipeTx.objectStore("products").clear()
  wipeTx.objectStore("meta").delete(META_KEY)
  await txComplete(wipeTx)

  return syncProducts()
}

export async function syncProducts() {
  const db = await openDb()

  const metaTx = db.transaction("meta", "readonly")
  const lastSync = await idbGet(metaTx.objectStore("meta"), META_KEY)

  const url = new URL(SYNC_URL, window.location.origin)
  if (lastSync?.value) url.searchParams.set("since", lastSync.value)

  const response = await fetch(url.toString(), {
    credentials: "same-origin",
    headers: { Accept: "application/json" },
  })

  if (!response.ok) throw new Error(`Sync failed: ${response.status}`)

  const { products, synced_at } = await response.json()

  const tx = db.transaction(["products", "meta"], "readwrite")
  const productStore = tx.objectStore("products")
  for (const product of products) {
    productStore.put(product)
  }
  tx.objectStore("meta").put({ key: META_KEY, value: synced_at })
  await txComplete(tx)

  return { count: products.length, synced_at }
}

export async function searchProducts(query) {
  if (!query || !query.trim()) return []

  const db = await openDb()
  const tx = db.transaction("products", "readonly")
  const store = tx.objectStore("products")

  // Try exact code match first
  const codeIndex = store.index("code")
  const exact = await idbGet(codeIndex, query.trim().toUpperCase())
  if (exact) return [exact]

  // Fall back to substring search across all products
  const all = await idbGetAll(store)
  const q = query.toLowerCase()
  return all
    .filter((p) => p.name.toLowerCase().includes(q) || p.code.toLowerCase().includes(q))
    .sort((a, b) => (b.sales_count ?? 0) - (a.sales_count ?? 0))
    .slice(0, 50)
}

export async function lookupByCode(code) {
  const db = await openDb()
  const tx = db.transaction("products", "readonly")
  const idx = tx.objectStore("products").index("code")
  return idbGet(idx, code.trim().toUpperCase())
}

export async function getLastSyncedAt() {
  const db = await openDb()
  const tx = db.transaction("meta", "readonly")
  const record = await idbGet(tx.objectStore("meta"), META_KEY)
  return record?.value ?? null
}

export async function getProductCount() {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction("products", "readonly")
    const req = tx.objectStore("products").count()
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}
