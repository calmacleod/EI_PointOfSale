<script>
  let { customer } = $props()

  const addressParts = $derived(
    [customer.address_line1, customer.address_line2, customer.city, customer.province, customer.postal_code]
      .filter(Boolean)
      .join(", ")
  )
</script>

<div class="card">
  <div class="card-body">
    <div class="card-name-row">
      <span class="card-name">{customer.name}</span>
      {#if customer.member_number}
        <span class="member-badge">#{customer.member_number}</span>
      {/if}
      {#if customer.alert}
        <span class="alert-badge" title={customer.alert}>!</span>
      {/if}
    </div>
    <div class="card-meta">
      {#if customer.email}
        <span class="meta-item">{customer.email}</span>
      {/if}
      {#if customer.phone}
        {#if customer.email}<span class="sep">·</span>{/if}
        <span class="meta-item">{customer.phone}</span>
      {/if}
      {#if addressParts}
        {#if customer.email || customer.phone}<span class="sep">·</span>{/if}
        <span class="meta-item address">{addressParts}</span>
      {/if}
    </div>
    {#if customer.alert}
      <div class="alert-text">{customer.alert}</div>
    {/if}
  </div>
</div>

<style>
  .card {
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
  }

  .card-name-row {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
  }

  .card-name {
    font-size: 14px;
    font-weight: 500;
    color: #1a1a2e;
  }

  .member-badge {
    font-size: 11px;
    font-weight: 500;
    color: #0d9488;
    background: #f0fdfb;
    border: 1px solid #99e6e0;
    border-radius: 4px;
    padding: 1px 5px;
    font-family: monospace;
  }

  .alert-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: #fef3c7;
    border: 1px solid #f59e0b;
    font-size: 10px;
    font-weight: 700;
    color: #b45309;
    cursor: default;
    flex-shrink: 0;
  }

  .card-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 3px;
    font-size: 12px;
    color: #6b6b6b;
    flex-wrap: wrap;
  }

  .meta-item {
    min-width: 0;
  }

  .address {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .sep {
    color: #c8c8c8;
    flex-shrink: 0;
  }

  .alert-text {
    margin-top: 6px;
    font-size: 12px;
    color: #b45309;
    background: #fffbeb;
    border: 1px solid #fde68a;
    border-radius: 4px;
    padding: 4px 8px;
  }
</style>
