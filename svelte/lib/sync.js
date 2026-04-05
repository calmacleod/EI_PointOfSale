import { openDb, idbGet, idbGetAll, txComplete } from "./db.js"

const SYNC_URL = "/api/v1/products/sync"
const META_KEY = "last_synced_at"

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

export async function getTopProducts(limit = 20) {
  const db = await openDb()
  const tx = db.transaction("products", "readonly")
  const all = await idbGetAll(tx.objectStore("products"))
  return all
    .sort((a, b) => (b.sales_count ?? 0) - (a.sales_count ?? 0))
    .slice(0, limit)
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

// --- Services ---

export async function syncServices() {
  return _syncCollection("services", "/api/v1/services/sync", "services_synced_at")
}

export async function fullSyncServices() {
  return _fullSyncCollection("services", "services_synced_at", syncServices)
}

export async function searchServices(query) {
  if (!query || !query.trim()) return []
  const db = await openDb()
  const all = await idbGetAll(db.transaction("services", "readonly").objectStore("services"))
  const q = query.toLowerCase()
  return all
    .filter((s) => s.name.toLowerCase().includes(q) || (s.code ?? "").toLowerCase().includes(q))
    .sort((a, b) => (b.sales_count ?? 0) - (a.sales_count ?? 0))
    .slice(0, 50)
}

// --- Tax Codes ---

export async function syncTaxCodes() {
  return _syncCollection("tax_codes", "/api/v1/tax_codes/sync", "tax_codes_synced_at")
}

export async function fullSyncTaxCodes() {
  return _fullSyncCollection("tax_codes", "tax_codes_synced_at", syncTaxCodes)
}

export async function getAllTaxCodes() {
  const db = await openDb()
  return idbGetAll(db.transaction("tax_codes", "readonly").objectStore("tax_codes"))
}

// --- Customers ---

export async function syncCustomers() {
  return _syncCollection("customers", "/api/v1/customers/sync", "customers_synced_at")
}

export async function fullSyncCustomers() {
  return _fullSyncCollection("customers", "customers_synced_at", syncCustomers)
}

export async function searchCustomers(query) {
  if (!query || !query.trim()) return []
  const db = await openDb()
  const all = await idbGetAll(db.transaction("customers", "readonly").objectStore("customers"))
  const q = query.toLowerCase()
  return all
    .filter(
      (c) =>
        c.name?.toLowerCase().includes(q) ||
        c.email?.toLowerCase().includes(q) ||
        c.member_number?.toLowerCase().includes(q) ||
        c.phone?.includes(q),
    )
    .slice(0, 50)
}

// --- Helpers ---

async function _syncCollection(storeName, url, metaKey) {
  const db = await openDb()

  const metaTx = db.transaction("meta", "readonly")
  const lastSync = await idbGet(metaTx.objectStore("meta"), metaKey)

  const fetchUrl = new URL(url, window.location.origin)
  if (lastSync?.value) fetchUrl.searchParams.set("since", lastSync.value)

  const response = await fetch(fetchUrl.toString(), {
    credentials: "same-origin",
    headers: { Accept: "application/json" },
  })

  if (!response.ok) throw new Error(`Sync failed (${storeName}): ${response.status}`)

  const data = await response.json()
  const records = data[storeName]
  const synced_at = data.synced_at

  const tx = db.transaction([storeName, "meta"], "readwrite")
  const store = tx.objectStore(storeName)
  for (const record of records) {
    store.put(record)
  }
  tx.objectStore("meta").put({ key: metaKey, value: synced_at })
  await txComplete(tx)

  return { count: records.length, synced_at }
}

async function _fullSyncCollection(storeName, metaKey, syncFn) {
  const db = await openDb()

  const wipeTx = db.transaction([storeName, "meta"], "readwrite")
  wipeTx.objectStore(storeName).clear()
  wipeTx.objectStore("meta").delete(metaKey)
  await txComplete(wipeTx)

  return syncFn()
}
