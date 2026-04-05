<script>
  import { onMount } from "svelte"
  import SearchBar from "./SearchBar.svelte"
  import CustomerCard from "./CustomerCard.svelte"
  import SyncStatus from "./SyncStatus.svelte"
  import { syncCustomers, fullSyncCustomers, searchCustomers } from "../lib/sync.js"
  import { openDb, idbGetAll } from "../lib/db.js"

  let query = $state("")
  let results = $state([])
  let syncing = $state(false)
  let lastSyncedAt = $state(null)
  let customerCount = $state(0)
  let syncError = $state(null)

  async function getAllCustomers() {
    const db = await openDb()
    return idbGetAll(db.transaction("customers", "readonly").objectStore("customers"))
  }

  async function getCustomerCount() {
    const db = await openDb()
    return new Promise((resolve, reject) => {
      const tx = db.transaction("customers", "readonly")
      const req = tx.objectStore("customers").count()
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => reject(req.error)
    })
  }

  async function getLastCustomerSyncedAt() {
    const { openDb: _openDb } = await import("../lib/db.js")
    const db = await _openDb()
    const tx = db.transaction("meta", "readonly")
    return new Promise((resolve, reject) => {
      const req = tx.objectStore("meta").get("customers_synced_at")
      req.onsuccess = () => resolve(req.result?.value ?? null)
      req.onerror = () => reject(req.error)
    })
  }

  async function refreshResults() {
    if (query.trim()) {
      results = await searchCustomers(query)
    } else {
      const all = await getAllCustomers()
      results = all.sort((a, b) => a.name.localeCompare(b.name))
    }
  }

  async function handleSearch(q) {
    query = q
    await refreshResults()
  }

  async function runSync() {
    syncing = true
    syncError = null
    try {
      const result = await syncCustomers()
      lastSyncedAt = result.synced_at
      customerCount = await getCustomerCount()
      await refreshResults()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  async function runFullSync() {
    syncing = true
    syncError = null
    customerCount = 0
    results = []
    try {
      const result = await fullSyncCustomers()
      lastSyncedAt = result.synced_at
      customerCount = await getCustomerCount()
      await refreshResults()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  onMount(async () => {
    lastSyncedAt = await getLastCustomerSyncedAt()
    customerCount = await getCustomerCount()
    await refreshResults()
    if (navigator.onLine) runSync()
  })
</script>

<div class="page">
  <div class="topbar">
    <div class="topbar-title">
      <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
      </svg>
      <h1 class="topbar-heading">Customers</h1>
    </div>
    <SyncStatus
      {syncing}
      {lastSyncedAt}
      {syncError}
      productCount={customerCount}
      countLabel="customers"
      onSync={runSync}
      onFullSync={runFullSync}
    />
  </div>

  <div class="search-section">
    <SearchBar onSearch={handleSearch} placeholder="Search by name, email, phone, or member number…" />
  </div>

  <div class="results-area">
    {#if results.length === 0}
      <div class="empty-state">
        <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
        </svg>
        <p class="empty-text">
          {#if query}
            No customers found for <span class="empty-query">"{query}"</span>
          {:else}
            No customers cached yet — sync to load data
          {/if}
        </p>
      </div>
    {:else}
      {#if !query}
        <p class="list-label">All customers</p>
      {/if}
      <div class="card-list">
        {#each results as customer (customer.id)}
          <CustomerCard {customer} />
        {/each}
      </div>
      {#if results.length === 50}
        <p class="limit-note">Showing first 50 results — refine your search</p>
      {/if}
    {/if}
  </div>
</div>

<style>
  .page {
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

  .empty-state {
    padding: 64px 0;
    text-align: center;
  }

  .empty-icon {
    display: block;
    margin: 0 auto 12px;
    width: 32px;
    height: 32px;
    color: #c8c8c8;
  }

  .empty-text {
    margin: 0;
    font-size: 14px;
    color: #6b6b6b;
  }

  .empty-query {
    font-weight: 500;
    color: #1a1a1a;
  }

  .list-label {
    margin: 0 0 8px;
    font-size: 11px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #8e8e9a;
  }

  .card-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .limit-note {
    margin: 12px 0 0;
    text-align: center;
    font-size: 12px;
    color: #6b6b6b;
  }
</style>
