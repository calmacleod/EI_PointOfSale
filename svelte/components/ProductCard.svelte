<script>
  let { product } = $props()

  const price = parseFloat(product.selling_price || "0")
  const taxRate = parseFloat(product.tax_rate || "0")
  const priceWithTax = price * (1 + taxRate)
  const isOutOfStock = product.stock_level !== null && product.stock_level <= 0

  function formatPrice(n) {
    return n.toLocaleString("en-CA", { style: "currency", currency: "CAD" })
  }
</script>

<div class="flex items-start justify-between rounded-lg border border-[#c8c8c8] bg-white p-3 transition hover:border-[#0d9488]/30 hover:bg-[#f0f0f0]">
  <div class="min-w-0 flex-1">
    <div class="flex items-center gap-2">
      <span class="truncate text-sm font-medium text-[#1a1a2e]">{product.name}</span>
      {#if isOutOfStock}
        <span class="shrink-0 rounded-full bg-red-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-red-700 border border-red-200">Out of stock</span>
      {/if}
    </div>
    <div class="mt-0.5 flex items-center gap-2 text-xs text-[#6b6b6b]">
      <span class="font-mono">{product.code}</span>
      {#if product.tax_code}
        <span>·</span>
        <span>{product.tax_code}</span>
      {/if}
      {#if product.stock_level !== null}
        <span>·</span>
        <span>{product.stock_level} in stock</span>
      {/if}
    </div>
  </div>
  <div class="ml-3 shrink-0 text-right">
    <div class="text-sm font-semibold text-[#1a1a2e]">{formatPrice(price)}</div>
    {#if taxRate > 0}
      <div class="text-xs text-[#6b6b6b]">{formatPrice(priceWithTax)} w/ tax</div>
    {/if}
  </div>
</div>
