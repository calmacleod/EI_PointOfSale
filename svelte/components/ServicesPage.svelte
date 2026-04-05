<script>
  import { onMount } from "svelte"
  import SearchBar from "./SearchBar.svelte"
  import ServiceCard from "./ServiceCard.svelte"
  import SyncStatus from "./SyncStatus.svelte"
  import { syncServices, fullSyncServices, searchServices } from "../lib/sync.js"
  import { openDb, idbGetAll } from "../lib/db.js"

  let query = $state("")
  let results = $state([])
  let syncing = $state(false)
  let lastSyncedAt = $state(null)
  let serviceCount = $state(0)
  let syncError = $state(null)

  async function getAllServices() {
    const db = await openDb()
    return idbGetAll(db.transaction("services", "readonly").objectStore("services"))
  }

  async function getServiceCount() {
    const db = await openDb()
    return new Promise((resolve, reject) => {
      const tx = db.transaction("services", "readonly")
      const req = tx.objectStore("services").count()
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => reject(req.error)
    })
  }

  async function getLastServiceSyncedAt() {
    const { openDb: _openDb, idbGet } = await import("../lib/db.js")
    const db = await _openDb()
    const tx = db.transaction("meta", "readonly")
    return new Promise((resolve, reject) => {
      const req = tx.objectStore("meta").get("services_synced_at")
      req.onsuccess = () => resolve(req.result?.value ?? null)
      req.onerror = () => reject(req.error)
    })
  }

  async function refreshResults() {
    if (query.trim()) {
      results = await searchServices(query)
    } else {
      const all = await getAllServices()
      results = all.sort((a, b) => (b.sales_count ?? 0) - (a.sales_count ?? 0))
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
      const result = await syncServices()
      lastSyncedAt = result.synced_at
      serviceCount = await getServiceCount()
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
    serviceCount = 0
    results = []
    try {
      const result = await fullSyncServices()
      lastSyncedAt = result.synced_at
      serviceCount = await getServiceCount()
      await refreshResults()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  onMount(async () => {
    lastSyncedAt = await getLastServiceSyncedAt()
    serviceCount = await getServiceCount()
    await refreshResults()
    if (navigator.onLine) runSync()
  })
</script>

<div class="page">
  <div class="topbar">
    <div class="topbar-title">
      <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
      </svg>
      <h1 class="topbar-heading">Services</h1>
    </div>
    <SyncStatus
      {syncing}
      {lastSyncedAt}
      {syncError}
      productCount={serviceCount}
      countLabel="services"
      onSync={runSync}
      onFullSync={runFullSync}
    />
  </div>

  <div class="search-section">
    <SearchBar onSearch={handleSearch} placeholder="Search services by name or code…" />
  </div>

  <div class="results-area">
    {#if results.length === 0}
      <div class="empty-state">
        <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        <p class="empty-text">
          {#if query}
            No services found for <span class="empty-query">"{query}"</span>
          {:else}
            No services cached yet — sync to load data
          {/if}
        </p>
      </div>
    {:else}
      {#if !query}
        <p class="list-label">All services</p>
      {/if}
      <div class="card-list">
        {#each results as service (service.id)}
          <ServiceCard {service} />
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
