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

<div class="flex min-w-0 flex-1 flex-col overflow-hidden">
  <!-- Top bar -->
  <div class="flex shrink-0 items-center justify-between border-b border-[#c8c8c8] bg-white px-4 py-2.5">
    <div class="flex items-center gap-2">
      <svg class="h-4 w-4 text-[#0d9488]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
      </svg>
      <h1 class="text-sm font-semibold text-[#1a1a2e]">Services</h1>
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

  <!-- Search -->
  <div class="shrink-0 border-b border-[#c8c8c8] bg-white px-4 py-3">
    <SearchBar onSearch={handleSearch} placeholder="Search services by name or code…" />
  </div>

  <!-- Results -->
  <div class="flex-1 overflow-y-auto px-4 py-3">
    {#if results.length === 0}
      <div class="py-16 text-center">
        <svg class="mx-auto mb-3 h-8 w-8 text-[#c8c8c8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        <p class="text-sm text-[#6b6b6b]">
          {#if query}
            No services found for <span class="font-medium text-[#1a1a1a]">"{query}"</span>
          {:else}
            No services cached yet — sync to load data
          {/if}
        </p>
      </div>
    {:else}
      {#if !query}
        <p class="mb-2 text-[11px] font-medium uppercase tracking-wider text-[#8e8e9a]">All services</p>
      {/if}
      <div class="space-y-1.5">
        {#each results as service (service.id)}
          <ServiceCard {service} />
        {/each}
      </div>
      {#if results.length === 50}
        <p class="mt-3 text-center text-xs text-[#6b6b6b]">Showing first 50 results — refine your search</p>
      {/if}
    {/if}
  </div>
</div>
