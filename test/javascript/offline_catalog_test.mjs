import assert from "node:assert/strict"
import { beforeEach, test } from "node:test"
import { IDBFactory } from "fake-indexeddb"
import { syncOfflineCollection, loadOfflineCatalogSummary, loadOfflineRecords } from "../../app/javascript/lib/offline-catalog.js"

globalThis.window = { location: { origin: "http://localhost" } }
const firstTime = "2026-10-23T10:00:00.123456Z"
const nextTime = "2026-10-23T10:01:00.123456Z"
const product = (id, code = `P${id}`) => ({ id, code, name: `Product ${id}` })
const page = (products, { deleted_ids = [], next_cursor = null, synced_at = firstTime } = {}) => ({
  ok: true, status: 200, json: async () => ({ products, deleted_ids, next_cursor, synced_at }),
})
const saved = async () => (await loadOfflineRecords("products")).sort((a, b) => a.id - b.id)
const summary = async () => (await loadOfflineCatalogSummary()).products

beforeEach(() => { globalThis.indexedDB = new IDBFactory() })

async function seed() {
  globalThis.fetch = async () => page([product(1), product(2)])
  await syncOfflineCollection("products", undefined, { full: true })
}

test("full sync follows every cursor and publishes only the complete catalog", async () => {
  await seed()
  let requests = 0
  globalThis.fetch = async (url, options) => {
    assert.equal(url.searchParams.get("page_size"), "500")
    assert.equal(url.searchParams.has("since"), false)
    assert.equal(options.credentials, "same-origin")
    assert.deepEqual(await saved(), [product(1), product(2)])
    assert.equal((await summary()).syncedAt, firstTime)
    requests++
    if (requests === 1) return page([product(3)], { next_cursor: "page-2", synced_at: nextTime })
    assert.equal(url.searchParams.get("cursor"), "page-2")
    return page([product(4)], { synced_at: nextTime })
  }
  assert.deepEqual(await syncOfflineCollection("products", undefined, { full: true }), {
    collection: "products", changed: 2, deleted: 0, syncedAt: nextTime,
  })
  assert.equal(requests, 2)
  assert.deepEqual(await saved(), [product(3), product(4)])
  assert.deepEqual(await summary(), { count: 2, syncedAt: nextTime })
})

test("failed full and delta pages preserve the old cache and timestamp, and retry starts cleanly", async () => {
  for (const full of [true, false]) {
    await seed()
    let requests = 0
    globalThis.fetch = async () => ++requests === 1
      ? page([product(3)], { deleted_ids: [1], next_cursor: "page-2", synced_at: nextTime })
      : { ok: false, status: 503 }
    await assert.rejects(syncOfflineCollection("products", undefined, { full }), /503/)
    assert.deepEqual(await saved(), [product(1), product(2)])
    assert.equal((await summary()).syncedAt, firstTime)
    globalThis.fetch = async (url) => {
      assert.equal(url.searchParams.has("cursor"), false)
      assert.equal(url.searchParams.get("since"), full ? null : firstTime)
      return page([product(4)], { deleted_ids: [1], synced_at: nextTime })
    }
    await syncOfflineCollection("products", undefined, { full })
    assert.deepEqual(await saved(), full ? [product(4)] : [product(2), product(4)])
  }
})

test("delta pages apply deletions and code swaps atomically", async () => {
  await seed()
  let requests = 0
  globalThis.fetch = async (url) => {
    assert.equal(url.searchParams.get("since"), firstTime)
    return ++requests === 1
      ? page([product(1, "P2")], { next_cursor: "page-2", synced_at: nextTime })
      : page([product(2, "P1")], { synced_at: nextTime })
  }
  await syncOfflineCollection("products")
  assert.deepEqual(await saved(), [product(1, "P2"), product(2, "P1")])
  globalThis.fetch = async () => page([], { deleted_ids: [1, 2], synced_at: nextTime })
  await syncOfflineCollection("products")
  assert.deepEqual(await saved(), [])
})

test("invalid pages, repeated cursors, changed boundaries and login redirects never advance the cache", async () => {
  await seed()
  for (const bad of [
    page([product(4)], { next_cursor: "page-2", synced_at: nextTime }),
    page([product(4)], { synced_at: firstTime }),
    { ok: true, redirected: true, status: 200 },
    { ok: true, json: async () => ({ synced_at: nextTime }) },
  ]) {
    let requests = 0
    globalThis.fetch = async () => ++requests === 1
      ? page([product(3)], { next_cursor: "page-2", synced_at: nextTime }) : bad
    await assert.rejects(syncOfflineCollection("products"))
    assert.deepEqual(await saved(), [product(1), product(2)])
    assert.equal((await summary()).syncedAt, firstTime)
  }
})

test("an IndexedDB commit failure rolls back records and the watermark", async () => {
  await seed()
  globalThis.fetch = async () => page([product(3, "P2")], { deleted_ids: [1], synced_at: nextTime })
  await assert.rejects(syncOfflineCollection("products"))
  assert.deepEqual(await saved(), [product(1), product(2)])
  assert.equal((await summary()).syncedAt, firstTime)
})

test("simultaneous collection syncs share one request sequence", async () => {
  let requests = 0
  globalThis.fetch = async () => { requests++; return page([product(1)]) }
  await Promise.all([syncOfflineCollection("products"), syncOfflineCollection("products")])
  assert.equal(requests, 1)
  assert.deepEqual(await saved(), [product(1)])
})

test("an old tab blocking the database upgrade gives actionable feedback and can be retried", async () => {
  const oldTab = await new Promise((resolve, reject) => {
    const request = indexedDB.open("ei_pos_offline", 3)
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
  await assert.rejects(syncOfflineCollection("products"), {
    name: "OfflineCatalogUpgradeBlocked", message: "Close other point-of-sale tabs, then try syncing again.",
  })
  oldTab.close()
  await new Promise((resolve) => setImmediate(resolve))
  await seed()
  assert.deepEqual(await saved(), [product(1), product(2)])
})
