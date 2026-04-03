<script>
  let { service } = $props()

  const price = parseFloat(service.price || "0")
  const taxRate = parseFloat(service.tax_rate || "0")
  const priceWithTax = price * (1 + taxRate)

  function formatPrice(n) {
    return n.toLocaleString("en-CA", { style: "currency", currency: "CAD" })
  }
</script>

<div class="flex items-start justify-between rounded-lg border border-[#c8c8c8] bg-white p-3 transition hover:border-[#0d9488]/30 hover:bg-[#f0f0f0]">
  <div class="min-w-0 flex-1">
    <div class="flex items-center gap-2">
      <span class="truncate text-sm font-medium text-[#1a1a2e]">{service.name}</span>
    </div>
    <div class="mt-0.5 flex items-center gap-2 text-xs text-[#6b6b6b]">
      {#if service.code}
        <span class="font-mono">{service.code}</span>
      {/if}
      {#if service.tax_code}
        {#if service.code}<span>·</span>{/if}
        <span>{service.tax_code}</span>
      {/if}
      {#if service.description}
        {#if service.code || service.tax_code}<span>·</span>{/if}
        <span class="truncate">{service.description}</span>
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
