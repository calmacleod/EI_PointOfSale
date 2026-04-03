<script>
  import { onMount } from "svelte"
  import TaxCodeCard from "./TaxCodeCard.svelte"
  import SyncStatus from "./SyncStatus.svelte"
  import { syncTaxCodes, fullSyncTaxCodes, getAllTaxCodes } from "../lib/sync.js"
  import { openDb, idbGet } from "../lib/db.js"

  let filter = $state("")
  let allTaxCodes = $state([])
  let syncing = $state(false)
  let lastSyncedAt = $state(null)
  let syncError = $state(null)

  async function getLastTaxCodeSyncedAt() {
    const db = await openDb()
    const tx = db.transaction("meta", "readonly")
    return new Promise((resolve, reject) => {
      const req = tx.objectStore("meta").get("tax_codes_synced_at")
      req.onsuccess = () => resolve(req.result?.value ?? null)
      req.onerror = () => reject(req.error)
    })
  }

  async function loadAll() {
    allTaxCodes = (await getAllTaxCodes()).sort((a, b) => a.code.localeCompare(b.code))
  }

  async function runSync() {
    syncing = true
    syncError = null
    try {
      const result = await syncTaxCodes()
      lastSyncedAt = result.synced_at
      await loadAll()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  async function runFullSync() {
    syncing = true
    syncError = null
    allTaxCodes = []
    try {
      const result = await fullSyncTaxCodes()
      lastSyncedAt = result.synced_at
      await loadAll()
    } catch (err) {
      syncError = navigator.onLine ? "Sync failed — try again" : "You are offline"
    } finally {
      syncing = false
    }
  }

  const filtered = $derived(
    filter.trim()
      ? allTaxCodes.filter(
          (t) =>
            t.code.toLowerCase().includes(filter.toLowerCase()) ||
            t.name.toLowerCase().includes(filter.toLowerCase()),
        )
      : allTaxCodes,
  )

  onMount(async () => {
    lastSyncedAt = await getLastTaxCodeSyncedAt()
    await loadAll()
    if (navigator.onLine) runSync()
  })
</script>

<div class="flex min-w-0 flex-1 flex-col overflow-hidden">
  <!-- Top bar -->
  <div class="flex shrink-0 items-center justify-between border-b border-[#c8c8c8] bg-white px-4 py-2.5">
    <div class="flex items-center gap-2">
      <svg class="h-4 w-4 text-[#0d9488]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/>
      </svg>
      <h1 class="text-sm font-semibold text-[#1a1a2e]">Tax Codes</h1>
    </div>
    <SyncStatus
      {syncing}
      {lastSyncedAt}
      {syncError}
      productCount={allTaxCodes.length}
      countLabel="tax codes"
      onSync={runSync}
      onFullSync={runFullSync}
    />
  </div>

  <!-- Filter -->
  <div class="shrink-0 border-b border-[#c8c8c8] bg-white px-4 py-3">
    <div class="relative">
      <svg class="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-[#8e8e9a]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
      </svg>
      <input
        type="text"
        bind:value={filter}
        placeholder="Filter by code or name…"
        class="w-full rounded-md border border-[#c8c8c8] bg-white py-2 pl-8 pr-3 text-sm placeholder-[#8e8e9a] focus:border-[#0d9488] focus:outline-none focus:ring-1 focus:ring-[#0d9488]"
      />
    </div>
  </div>

  <!-- List -->
  <div class="flex-1 overflow-y-auto px-4 py-3">
    {#if filtered.length === 0}
      <div class="py-16 text-center">
        <svg class="mx-auto mb-3 h-8 w-8 text-[#c8c8c8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/>
        </svg>
        <p class="text-sm text-[#6b6b6b]">
          {#if filter}
            No tax codes found for <span class="font-medium text-[#1a1a1a]">"{filter}"</span>
          {:else}
            No tax codes cached yet — sync to load data
          {/if}
        </p>
      </div>
    {:else}
      <p class="mb-2 text-[11px] font-medium uppercase tracking-wider text-[#8e8e9a]">{filtered.length} tax code{filtered.length === 1 ? "" : "s"}</p>
      <div class="space-y-1.5">
        {#each filtered as taxCode (taxCode.id)}
          <TaxCodeCard {taxCode} />
        {/each}
      </div>
    {/if}
  </div>
</div>
