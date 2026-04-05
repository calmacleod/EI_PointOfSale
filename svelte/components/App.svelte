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

<div class="app-layout">
  <Sidebar {activePage} onNavigate={(page) => (activePage = page)} />

  {#if activePage === "products"}
    <div class="main-content">
      <div class="topbar">
        <div class="topbar-title">
          <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <h1 class="topbar-heading">Product Lookup</h1>
        </div>
        <SyncStatus {syncing} {lastSyncedAt} {syncError} {productCount} onSync={runSync} onFullSync={runFullSync} />
      </div>

      <div class="search-section">
        <SearchBar onSearch={handleSearch} />
      </div>

      <div class="results-area">
        <ProductList products={results} {query} topN={TOP_N} />
      </div>
    </div>
  {:else if activePage === "services"}
    <ServicesPage />
  {:else if activePage === "tax_codes"}
    <TaxCodesPage />
  {/if}
</div>

<style>
  .app-layout {
    display: flex;
    height: 100vh;
    overflow: hidden;
    background: #f0f0f0;
    font-family: Inter, system-ui, sans-serif;
    color: #1a1a1a;
  }

  .main-content {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    border-bottom: 1px solid #c8c8c8;
    background: white;
    padding: 10px 16px;
  }

  .topbar-title {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .topbar-icon {
    width: 16px;
    height: 16px;
    color: #0d9488;
    flex-shrink: 0;
  }

  .topbar-heading {
    font-size: 14px;
    font-weight: 600;
    color: #1a1a2e;
    margin: 0;
  }

  .search-section {
    flex-shrink: 0;
    border-bottom: 1px solid #c8c8c8;
    background: white;
    padding: 12px 16px;
  }

  .results-area {
    flex: 1;
    overflow-y: auto;
    padding: 12px 16px;
  }
</style>
