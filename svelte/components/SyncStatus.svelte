<script>
  let { syncing = false, lastSyncedAt = null, syncError = null, productCount = 0, onSync, onFullSync } = $props()

  let confirmingFullSync = $state(false)

  function formatTime(iso) {
    if (!iso) return "Never"
    return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
</script>

<div class="flex items-center gap-3 text-sm">
  <div class="flex items-center gap-2">
    <div class="h-1.5 w-1.5 rounded-full {syncing ? 'bg-amber-500 animate-pulse' : syncError ? 'bg-red-500' : 'bg-[#0d9488]'}"></div>
    {#if syncError}
      <span class="text-[12px] text-red-600">{syncError}</span>
    {:else if syncing}
      <span class="text-[12px] text-amber-600">Syncing…</span>
    {:else}
      <span class="text-[12px] text-[#6b6b6b]">{productCount} products · {formatTime(lastSyncedAt)}</span>
    {/if}
  </div>

  <button
    onclick={onSync}
    disabled={syncing}
    class="rounded px-2 py-1 text-[11px] font-medium text-[#555566] hover:bg-black/4 hover:text-[#1a1a2e] disabled:opacity-40"
  >
    Sync now
  </button>

  {#if confirmingFullSync}
    <div class="flex items-center gap-1.5">
      <span class="text-[11px] text-[#6b6b6b]">Wipe &amp; re-sync?</span>
      <button
        onclick={() => { confirmingFullSync = false; onFullSync() }}
        disabled={syncing}
        class="rounded bg-red-50 px-2 py-1 text-[11px] font-medium text-red-700 hover:bg-red-100 disabled:opacity-40"
      >
        Yes
      </button>
      <button
        onclick={() => confirmingFullSync = false}
        class="rounded px-2 py-1 text-[11px] font-medium text-[#555566] hover:bg-black/4 hover:text-[#1a1a2e]"
      >
        Cancel
      </button>
    </div>
  {:else}
    <button
      onclick={() => confirmingFullSync = true}
      disabled={syncing}
      class="rounded px-2 py-1 text-[11px] font-medium text-[#8e8e9a] hover:bg-black/4 hover:text-red-600 disabled:opacity-40"
      title="Wipe all cached data and re-sync from scratch"
    >
      Full re-sync
    </button>
  {/if}
</div>
