<script>
  let { service } = $props()

  const price = parseFloat(service.price || "0")
  const taxRate = parseFloat(service.tax_rate || "0")
  const priceWithTax = price * (1 + taxRate)

  function formatPrice(n) {
    return n.toLocaleString("en-CA", { style: "currency", currency: "CAD" })
  }
</script>

<div class="card">
  <div class="card-body">
    <div class="card-name-row">
      <span class="card-name">{service.name}</span>
    </div>
    <div class="card-meta">
      {#if service.code}
        <span class="card-code">{service.code}</span>
      {/if}
      {#if service.tax_code}
        {#if service.code}<span class="sep">·</span>{/if}
        <span>{service.tax_code}</span>
      {/if}
      {#if service.description}
        {#if service.code || service.tax_code}<span class="sep">·</span>{/if}
        <span class="description">{service.description}</span>
      {/if}
    </div>
  </div>
  <div class="card-price">
    <div class="price-main">{formatPrice(price)}</div>
    {#if taxRate > 0}
      <div class="price-tax">{formatPrice(priceWithTax)} w/ tax</div>
    {/if}
  </div>
</div>

<style>
  .card {
    display: flex;
    align-items: flex-start;
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

  .card-name {
    font-size: 14px;
    font-weight: 500;
    color: #1a1a2e;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .card-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 2px;
    font-size: 12px;
    color: #6b6b6b;
  }

  .card-code {
    font-family: monospace;
  }

  .sep {
    color: #c8c8c8;
  }

  .description {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .card-price {
    margin-left: 12px;
    flex-shrink: 0;
    text-align: right;
  }

  .price-main {
    font-size: 14px;
    font-weight: 600;
    color: #1a1a2e;
  }

  .price-tax {
    font-size: 12px;
    color: #6b6b6b;
  }
</style>
