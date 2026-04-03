<script>
  import { onMount } from "svelte"
  import SearchBar from "./SearchBar.svelte"
  import ProductList from "./ProductList.svelte"
  import SyncStatus from "./SyncStatus.svelte"
  import Sidebar from "./Sidebar.svelte"
  import ServicesPage from "./ServicesPage.svelte"
  import TaxCodesPage from "./TaxCodesPage.svelte"
  import { syncProducts, fullSyncProducts, searchProducts, getTopProducts, getLastSyncedAt, getProductCount } from "../lib/sync.js"

  const TOP_N = 20

  let activePage = $state("products")
  let query = $state("")
  let results = $state([])
  let syncing = $state(false)
  let lastSyncedAt = $state(null)
  let productCount = $state(0)
  let syncError = $state(null)

  async function refreshResults() {
    results = query.trim() ? await searchProducts(query) : await getTopProducts(TOP_N)
  }

  async function handleSearch(q) {
    query = q
    await refreshResults()
  }

  async function runFullSync() {
    syncing = true
    syncError = null
    productCount = 0
    results = []
    try {
      const result = await fullSyncProducts()
      lastSyncedAt = result.synced_at
      productCount = await getProductCount()
      await refreshResults()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  async function runSync() {
    syncing = true
    syncError = null
    try {
      const result = await syncProducts()
      lastSyncedAt = result.synced_at
      productCount = await getProductCount()
      await refreshResults()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  onMount(async () => {
    lastSyncedAt = await getLastSyncedAt()
    productCount = await getProductCount()
    results = await getTopProducts(TOP_N)
    if (navigator.onLine) runSync()
  })
</script>

<div class="flex h-screen overflow-hidden bg-[#f0f0f0] font-[Inter,system-ui,sans-serif] text-[#1a1a1a]">
  <Sidebar {activePage} onNavigate={(page) => (activePage = page)} />

  {#if activePage === "products"}
    <!-- Main content: Products -->
    <div class="flex min-w-0 flex-1 flex-col overflow-hidden">
      <div class="flex shrink-0 items-center justify-between border-b border-[#c8c8c8] bg-white px-4 py-2.5">
        <div class="flex items-center gap-2">
          <svg class="h-4 w-4 text-[#0d9488]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <h1 class="text-sm font-semibold text-[#1a1a2e]">Product Lookup</h1>
        </div>
        <SyncStatus {syncing} {lastSyncedAt} {syncError} {productCount} onSync={runSync} onFullSync={runFullSync} />
      </div>

      <div class="shrink-0 border-b border-[#c8c8c8] bg-white px-4 py-3">
        <SearchBar onSearch={handleSearch} />
      </div>

      <div class="flex-1 overflow-y-auto px-4 py-3">
        <ProductList products={results} {query} topN={TOP_N} />
      </div>
    </div>
  {:else if activePage === "services"}
    <ServicesPage />
  {:else if activePage === "tax_codes"}
    <TaxCodesPage />
  {/if}
</div>
