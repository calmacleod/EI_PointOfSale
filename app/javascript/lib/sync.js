// Compatibility exports for the remaining development-tool controllers.
// The native Inertia/Svelte offline screen uses offline-catalog.js directly.
import {
  loadOfflineCatalogSummary,
  loadOfflineRecords,
  syncOfflineCollection,
} from "./offline-catalog.js"

export async function syncProducts() {
  const result = await syncOfflineCollection("products")
  return { count: result.changed, synced_at: result.syncedAt }
}

export async function fullSyncProducts() {
  const result = await syncOfflineCollection("products", undefined, { full: true })
  return { count: result.changed, synced_at: result.syncedAt }
}

export function searchProducts(query) {
  return loadOfflineRecords("products", query)
}

export async function lookupByCode(code) {
  const matches = await loadOfflineRecords("products", code)
  return matches.find((product) => product.code?.toLowerCase() === code.trim().toLowerCase()) || null
}

export async function getLastSyncedAt() {
  const summary = await loadOfflineCatalogSummary()
  return summary.products.syncedAt
}

export async function getProductCount() {
  const summary = await loadOfflineCatalogSummary()
  return summary.products.count
}
