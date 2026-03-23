<script>
  import { onMount } from "svelte"
  import SearchBar from "./SearchBar.svelte"
  import ProductList from "./ProductList.svelte"
  import SyncStatus from "./SyncStatus.svelte"
  import { syncProducts, searchProducts, getLastSyncedAt, getProductCount } from "../lib/sync.js"

  let query = $state("")
  let results = $state([])
  let syncing = $state(false)
  let lastSyncedAt = $state(null)
  let productCount = $state(0)
  let syncError = $state(null)

  async function handleSearch(q) {
    query = q
    results = q.trim() ? await searchProducts(q) : []
  }

  async function runSync() {
    syncing = true
    syncError = null
    try {
      const result = await syncProducts()
      lastSyncedAt = result.synced_at
      productCount = await getProductCount()
      // Refresh current search results after sync
      if (query.trim()) results = await searchProducts(query)
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  onMount(async () => {
    lastSyncedAt = await getLastSyncedAt()
    productCount = await getProductCount()
    // Auto-sync on mount if online
    if (navigator.onLine) runSync()
  })
</script>

<div class="flex h-screen flex-col bg-[var(--page-bg,#111827)] text-[var(--body-text,#e5e7eb)]" style="--page-bg: #111827; --body-text: #e5e7eb; --sidebar-text: #9ca3af; --sidebar-text-bright: #f3f4f6;">
  <!-- Header -->
  <div class="flex items-center justify-between border-b border-white/10 px-4 py-3">
    <div class="flex items-center gap-2.5">
      <svg class="h-5 w-5 text-white opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M18.364 5.636a9 9 0 010 12.728M15.536 8.464a5 5 0 010 7.072M12 12h.01M8.464 15.536a5 5 0 010-7.072M5.636 18.364a9 9 0 010-12.728"/>
      </svg>
      <h1 class="text-sm font-semibold text-white">Offline Mode</h1>
    </div>
    <a href="/" class="rounded px-2.5 py-1 text-xs font-medium text-[var(--sidebar-text)] transition hover:bg-white/10 hover:text-white">
      Back to POS
    </a>
  </div>

  <!-- Sync status bar -->
  <div class="border-b border-white/10 px-4 py-2">
    <SyncStatus {syncing} {lastSyncedAt} {syncError} {productCount} onSync={runSync} />
  </div>

  <!-- Search -->
  <div class="border-b border-white/10 px-4 py-3">
    <SearchBar onSearch={handleSearch} />
  </div>

  <!-- Results -->
  <div class="flex-1 overflow-y-auto px-4 py-3">
    <ProductList products={results} {query} />
  </div>
</div>
