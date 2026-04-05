<script>
  let { taxCode } = $props()

  const rate = $derived(parseFloat(taxCode.rate || "0"))
  const ratePercent = $derived((rate * 100).toFixed(rate === 0 ? 0 : 2).replace(/\.?0+$/, "") + "%")
  const isExempt = $derived(rate === 0)
</script>

<div class="card">
  <div class="card-body">
    <div class="card-name-row">
      <span class="card-code">{taxCode.code}</span>
      <span class="card-name">{taxCode.name}</span>
    </div>
    <div class="card-meta">
      {#if taxCode.province_code}
        <span>{taxCode.province_code}</span>
      {/if}
      {#if taxCode.exemption_type}
        {#if taxCode.province_code}<span class="sep">·</span>{/if}
        <span>{taxCode.exemption_type}</span>
      {/if}
      {#if taxCode.notes}
        {#if taxCode.province_code || taxCode.exemption_type}<span class="sep">·</span>{/if}
        <span class="notes">{taxCode.notes}</span>
      {/if}
    </div>
  </div>
  <div class="card-rate">
    <span class="rate-badge" class:exempt={isExempt} class:taxed={!isExempt}>
      {ratePercent}
    </span>
  </div>
</div>

<style>
  .card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-radius: 8px;
    border: 1px solid #c8c8c8;
    background: white;
    padding: 12px;
    transition: border-color 0.15s, background 0.15s;
  }

  .card:hover {
    border-color: rgba(13, 148, 136, 0.3);
    background: #f0f0f0;
  }

  .card-body {
    min-width: 0;
    flex: 1;
  }

  .card-name-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .card-code {
    font-family: monospace;
    font-size: 14px;
    font-weight: 600;
    color: #1a1a2e;
  }

  .card-name {
    font-size: 14px;
    color: #6b6b6b;
  }

  .card-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 2px;
    font-size: 12px;
    color: #6b6b6b;
  }

  .sep {
    color: #c8c8c8;
  }

  .notes {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .card-rate {
    margin-left: 12px;
    flex-shrink: 0;
  }

  .rate-badge {
    display: inline-block;
    border-radius: 9999px;
    padding: 2px 8px;
    font-size: 11px;
    font-weight: 600;
  }

  .rate-badge.exempt {
    background: #f1f5f9;
    color: #475569;
    border: 1px solid #cbd5e1;
  }

  .rate-badge.taxed {
    background: #f0fdfa;
    color: #0f766e;
    border: 1px solid #99f6e4;
  }
</style>
