<script>
  let { product } = $props()

  const price = $derived(parseFloat(product.selling_price || "0"))
  const taxRate = $derived(parseFloat(product.tax_rate || "0"))
  const priceWithTax = $derived(price * (1 + taxRate))
  const isOutOfStock = $derived(product.stock_level !== null && product.stock_level <= 0)

  function formatPrice(n) {
    return n.toLocaleString("en-CA", { style: "currency", currency: "CAD" })
  }
</script>

<div class="card">
  <div class="card-body">
    <div class="card-name-row">
      <span class="card-name">{product.name}</span>
      {#if isOutOfStock}
        <span class="badge badge--out-of-stock">Out of stock</span>
      {/if}
    </div>
    <div class="card-meta">
      <span class="card-code">{product.code}</span>
      {#if product.tax_code}
        <span class="sep">·</span>
        <span>{product.tax_code}</span>
      {/if}
      {#if product.stock_level !== null}
        <span class="sep">·</span>
        <span>{product.stock_level} in stock</span>
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

  .badge {
    flex-shrink: 0;
    border-radius: 9999px;
    padding: 2px 6px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .badge--out-of-stock {
    background: #fee2e2;
    color: #b91c1c;
    border: 1px solid #fecaca;
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
