<script>
  let { syncing = false, lastSyncedAt = null, syncError = null, productCount = 0, onSync } = $props()

  function formatTime(iso) {
    if (!iso) return "Never"
    const d = new Date(iso)
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
</script>

<div class="flex items-center justify-between rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-sm">
  <div class="flex items-center gap-3">
    <div class="flex h-2 w-2 rounded-full {syncing ? 'bg-amber-400 animate-pulse' : syncError ? 'bg-red-400' : 'bg-green-400'}"></div>
    <div>
      {#if syncError}
        <span class="text-red-400">{syncError}</span>
      {:else if syncing}
        <span class="text-amber-300">Syncing products…</span>
      {:else}
        <span class="text-[var(--sidebar-text)]">
          {productCount} products · Last sync: {formatTime(lastSyncedAt)}
        </span>
      {/if}
    </div>
  </div>
  <button
    onclick={onSync}
    disabled={syncing}
    class="rounded px-2 py-1 text-xs font-medium text-[var(--sidebar-text)] transition hover:bg-white/10 disabled:opacity-40"
  >
    Sync now
  </button>
</div>
