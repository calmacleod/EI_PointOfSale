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

<div class="page">
  <div class="topbar">
    <div class="topbar-title">
      <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/>
      </svg>
      <h1 class="topbar-heading">Tax Codes</h1>
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

  <div class="filter-section">
    <div class="filter-wrap">
      <svg class="filter-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
      </svg>
      <input
        type="text"
        bind:value={filter}
        placeholder="Filter by code or name…"
        class="filter-input"
      />
    </div>
  </div>

  <div class="results-area">
    {#if filtered.length === 0}
      <div class="empty-state">
        <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z"/>
        </svg>
        <p class="empty-text">
          {#if filter}
            No tax codes found for <span class="empty-query">"{filter}"</span>
          {:else}
            No tax codes cached yet — sync to load data
          {/if}
        </p>
      </div>
    {:else}
      <p class="list-label">{filtered.length} tax code{filtered.length === 1 ? "" : "s"}</p>
      <div class="card-list">
        {#each filtered as taxCode (taxCode.id)}
          <TaxCodeCard {taxCode} />
        {/each}
      </div>
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

  .filter-section {
    flex-shrink: 0;
    border-bottom: 1px solid #c8c8c8;
    background: white;
    padding: 12px 16px;
  }

  .filter-wrap {
    position: relative;
  }

  .filter-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    width: 14px;
    height: 14px;
    color: #8e8e9a;
    pointer-events: none;
  }

  .filter-input {
    width: 100%;
    box-sizing: border-box;
    border-radius: 6px;
    border: 1px solid #c8c8c8;
    background: white;
    padding: 8px 12px 8px 32px;
    font-size: 14px;
    color: #1a1a1a;
    outline: none;
    transition: border-color 0.15s, box-shadow 0.15s;
  }

  .filter-input::placeholder {
    color: #8e8e9a;
  }

  .filter-input:focus {
    border-color: #0d9488;
    box-shadow: 0 0 0 1px #0d9488;
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
</style>
