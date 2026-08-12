const DB_NAME = "ei_pos_offline"
const DB_VERSION = 3
const REFRESH_INTERVAL_MS = 60 * 60 * 1000
const REFRESHED_AT_KEY = "ei-pos-offline-catalog-refreshed-at"
const CATALOG_EVENT = "ei-pos-offline-catalog"

export const DEFAULT_SYNC_PATHS = {
  products: "/api/v1/products/sync",
  services: "/api/v1/services/sync",
  customers: "/api/v1/customers/sync",
  tax_codes: "/api/v1/tax_codes/sync",
}

export const COLLECTIONS = {
  products: { label: "Products", singular: "product", metaKey: "last_synced_at" },
  services: { label: "Services", singular: "service", metaKey: "services_synced_at" },
  customers: { label: "Customers", singular: "customer", metaKey: "customers_synced_at" },
  tax_codes: { label: "Tax codes", singular: "tax code", metaKey: "tax_codes_synced_at" },
}

let catalogSyncPromise = null
let warmPromise = null

export function openOfflineDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = (event) => {
      const db = event.target.result

      if (!db.objectStoreNames.contains("products")) {
        const products = db.createObjectStore("products", { keyPath: "id" })
        products.createIndex("code", "code", { unique: true })
        products.createIndex("name", "name", { unique: false })
        products.createIndex("sales_count", "sales_count", { unique: false })
      } else {
        const products = event.target.transaction.objectStore("products")
        if (!products.indexNames.contains("sales_count")) {
          products.createIndex("sales_count", "sales_count", { unique: false })
        }
      }

      if (!db.objectStoreNames.contains("services")) {
        const services = db.createObjectStore("services", { keyPath: "id" })
        services.createIndex("code", "code", { unique: false })
        services.createIndex("name", "name", { unique: false })
      }

      if (!db.objectStoreNames.contains("customers")) {
        const customers = db.createObjectStore("customers", { keyPath: "id" })
        customers.createIndex("name", "name", { unique: false })
        customers.createIndex("member_number", "member_number", { unique: false })
        customers.createIndex("email", "email", { unique: false })
      }

      if (!db.objectStoreNames.contains("tax_codes")) {
        const taxCodes = db.createObjectStore("tax_codes", { keyPath: "id" })
        taxCodes.createIndex("code", "code", { unique: true })
      }

      if (!db.objectStoreNames.contains("meta")) {
        db.createObjectStore("meta", { keyPath: "key" })
      }
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

export async function loadOfflineRecords(collection, query = "") {
  assertCollection(collection)
  const db = await openOfflineDb()
  const records = await getAll(db.transaction(collection, "readonly").objectStore(collection))
  const term = query.trim().toLowerCase()

  if (collection === "products") {
    if (!term) return sortBySales(records).slice(0, 20)

    const exact = records.find((record) => record.code?.toLowerCase() === term)
    if (exact) return [exact]

    return sortBySales(records.filter((record) => matches(record, term, ["name", "code"]))).slice(0, 50)
  }

  if (collection === "services") {
    const matchesQuery = term ? records.filter((record) => matches(record, term, ["name", "code", "description"])) : records
    const sorted = sortBySales(matchesQuery)
    return term ? sorted.slice(0, 50) : sorted
  }

  if (collection === "customers") {
    const matchesQuery = term ? records.filter((record) => matches(record, term, ["name", "email", "member_number", "phone"])) : records
    const sorted = matchesQuery.sort((left, right) => stringValue(left.name).localeCompare(stringValue(right.name)))
    return term ? sorted.slice(0, 50) : sorted
  }

  const matchesQuery = term ? records.filter((record) => matches(record, term, ["code", "name", "province_code", "exemption_type"])) : records
  return matchesQuery.sort((left, right) => stringValue(left.code).localeCompare(stringValue(right.code)))
}

export async function loadOfflineCatalogSummary() {
  const db = await openOfflineDb()

  return Object.fromEntries(
    await Promise.all(
      Object.entries(COLLECTIONS).map(async ([collection, config]) => {
        const count = await countRecords(db, collection)
        const meta = await getRecord(db.transaction("meta", "readonly").objectStore("meta"), config.metaKey)
        return [collection, { count, syncedAt: meta?.value || null }]
      }),
    ),
  )
}

export async function syncOfflineCollection(collection, paths = DEFAULT_SYNC_PATHS, { full = false } = {}) {
  assertCollection(collection)
  const db = await openOfflineDb()
  const config = COLLECTIONS[collection]
  const meta = await getRecord(db.transaction("meta", "readonly").objectStore("meta"), config.metaKey)
  const url = new URL(paths[collection] || DEFAULT_SYNC_PATHS[collection], window.location.origin)

  if (!full && meta?.value) url.searchParams.set("since", meta.value)

  const response = await fetch(url, {
    credentials: "same-origin",
    headers: { Accept: "application/json" },
  })

  if (!response.ok || response.redirected) {
    throw new Error(`Could not sync ${config.label.toLowerCase()} (${response.status})`)
  }

  const data = await response.json()
  const records = Array.isArray(data[collection]) ? data[collection] : []
  const deletedIds = Array.isArray(data.deleted_ids) ? data.deleted_ids : []
  const transaction = db.transaction([collection, "meta"], "readwrite")
  const store = transaction.objectStore(collection)

  if (full) store.clear()
  for (const id of deletedIds) store.delete(id)
  for (const record of records) store.put(record)
  transaction.objectStore("meta").put({ key: config.metaKey, value: data.synced_at })
  await transactionComplete(transaction)

  return { collection, changed: records.length, deleted: deletedIds.length, syncedAt: data.synced_at }
}

export async function syncOfflineCatalog(paths = DEFAULT_SYNC_PATHS, options = {}) {
  if (catalogSyncPromise) return catalogSyncPromise

  catalogSyncPromise = Promise.allSettled(
    Object.keys(COLLECTIONS).map((collection) => syncOfflineCollection(collection, paths, options)),
  ).then(async (outcomes) => {
    const summary = await loadOfflineCatalogSummary()
    dispatchCatalogUpdate(summary)

    const failed = outcomes.find((outcome) => outcome.status === "rejected")
    if (failed) throw failed.reason

    return { results: outcomes.map((outcome) => outcome.value), summary }
  }).finally(() => {
    catalogSyncPromise = null
  })

  return catalogSyncPromise
}

export function warmOfflineCatalog(paths = DEFAULT_SYNC_PATHS) {
  if (warmPromise) return warmPromise
  if (!shouldRefreshCatalog()) return Promise.resolve(null)

  warmPromise = syncOfflineCatalog(paths)
    .then((result) => {
      writeStorageValue(REFRESHED_AT_KEY, new Date().toISOString())
      return result
    })
    .catch(() => null)
    .finally(() => {
      warmPromise = null
    })

  return warmPromise
}

function shouldRefreshCatalog() {
  const refreshedAt = Date.parse(readStorageValue(REFRESHED_AT_KEY))
  return !Number.isFinite(refreshedAt) || Date.now() - refreshedAt >= REFRESH_INTERVAL_MS
}

function assertCollection(collection) {
  if (!COLLECTIONS[collection]) throw new Error(`Unknown offline collection: ${collection}`)
}

function matches(record, term, fields) {
  return fields.some((field) => stringValue(record[field]).toLowerCase().includes(term))
}

function sortBySales(records) {
  return records.sort((left, right) => Number(right.sales_count || 0) - Number(left.sales_count || 0))
}

function stringValue(value) {
  return value == null ? "" : String(value)
}

function dispatchCatalogUpdate(summary) {
  if (typeof window === "undefined") return
  window.dispatchEvent(new CustomEvent(CATALOG_EVENT, { detail: summary }))
}

function readStorageValue(key) {
  try {
    return window.localStorage.getItem(key)
  } catch (_error) {
    return null
  }
}

function writeStorageValue(key, value) {
  try {
    window.localStorage.setItem(key, value)
  } catch (_error) {
    // Refresh throttling is best-effort. IndexedDB remains the source of truth.
  }
}

function getRecord(source, key) {
  return requestResult(source.get(key), null)
}

function getAll(store) {
  return requestResult(store.getAll(), [])
}

function countRecords(db, collection) {
  return requestResult(db.transaction(collection, "readonly").objectStore(collection).count(), 0)
}

function requestResult(request, fallback) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result ?? fallback)
    request.onerror = () => reject(request.error)
  })
}

function transactionComplete(transaction) {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = resolve
    transaction.onerror = () => reject(transaction.error)
    transaction.onabort = () => reject(transaction.error)
  })
}
