<script>
  let { syncing = false, lastSyncedAt = null, syncError = null, productCount = 0, countLabel = "products", onSync, onFullSync } = $props()

  let confirmingFullSync = $state(false)

  function formatTime(iso) {
    if (!iso) return "Never"
    return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
</script>

<div class="sync-bar">
  <div class="sync-status">
    <div
      class="status-dot"
      class:syncing={syncing}
      class:error={!syncing && syncError}
      class:ok={!syncing && !syncError}
    ></div>
    {#if syncError}
      <span class="status-text status-text--error">{syncError}</span>
    {:else if syncing}
      <span class="status-text status-text--syncing">Syncing…</span>
    {:else}
      <span class="status-text">{productCount} {countLabel} · {formatTime(lastSyncedAt)}</span>
    {/if}
  </div>

  <button onclick={onSync} disabled={syncing} class="btn-subtle">
    Sync now
  </button>

  {#if confirmingFullSync}
    <div class="confirm-row">
      <span class="confirm-label">Wipe &amp; re-sync?</span>
      <button
        onclick={() => { confirmingFullSync = false; onFullSync() }}
        disabled={syncing}
        class="btn-danger"
      >
        Yes
      </button>
      <button
        onclick={() => confirmingFullSync = false}
        class="btn-subtle"
      >
        Cancel
      </button>
    </div>
  {:else}
    <button
      onclick={() => confirmingFullSync = true}
      disabled={syncing}
      class="btn-subtle btn-muted"
      title="Wipe all cached data and re-sync from scratch"
    >
      Full re-sync
    </button>
  {/if}
</div>

<style>
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .sync-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 14px;
  }

  .sync-status {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #0d9488;
  }

  .status-dot.syncing {
    background: #f59e0b;
    animation: pulse 1.2s ease-in-out infinite;
  }

  .status-dot.error {
    background: #ef4444;
  }

  .status-text {
    font-size: 12px;
    color: #6b6b6b;
  }

  .status-text--error {
    color: #dc2626;
  }

  .status-text--syncing {
    color: #d97706;
  }

  .btn-subtle {
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 11px;
    font-weight: 500;
    color: #555566;
    background: transparent;
    border: none;
    cursor: pointer;
    transition: background 0.1s, color 0.1s;
  }

  .btn-subtle:hover {
    background: rgba(0, 0, 0, 0.04);
    color: #1a1a2e;
  }

  .btn-subtle:disabled {
    opacity: 0.4;
    cursor: default;
  }

  .btn-muted {
    color: #8e8e9a;
  }

  .btn-muted:hover {
    color: #dc2626;
  }

  .btn-danger {
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 11px;
    font-weight: 500;
    color: #b91c1c;
    background: #fef2f2;
    border: none;
    cursor: pointer;
    transition: background 0.1s;
  }

  .btn-danger:hover {
    background: #fee2e2;
  }

  .btn-danger:disabled {
    opacity: 0.4;
    cursor: default;
  }

  .confirm-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .confirm-label {
    font-size: 11px;
    color: #6b6b6b;
  }
</style>
