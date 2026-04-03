<script>
  let { taxCode } = $props()

  const rate = parseFloat(taxCode.rate || "0")
  const ratePercent = (rate * 100).toFixed(rate === 0 ? 0 : 2).replace(/\.?0+$/, "") + "%"
  const isExempt = rate === 0
</script>

<div class="flex items-center justify-between rounded-lg border border-[#c8c8c8] bg-white p-3 transition hover:border-[#0d9488]/30 hover:bg-[#f0f0f0]">
  <div class="min-w-0 flex-1">
    <div class="flex items-center gap-2">
      <span class="font-mono text-sm font-semibold text-[#1a1a2e]">{taxCode.code}</span>
      <span class="text-sm text-[#6b6b6b]">{taxCode.name}</span>
    </div>
    <div class="mt-0.5 flex items-center gap-2 text-xs text-[#6b6b6b]">
      {#if taxCode.province_code}
        <span>{taxCode.province_code}</span>
      {/if}
      {#if taxCode.exemption_type}
        {#if taxCode.province_code}<span>·</span>{/if}
        <span>{taxCode.exemption_type}</span>
      {/if}
      {#if taxCode.notes}
        {#if taxCode.province_code || taxCode.exemption_type}<span>·</span>{/if}
        <span class="truncate">{taxCode.notes}</span>
      {/if}
    </div>
  </div>
  <div class="ml-3 shrink-0">
    <span class="rounded-full px-2 py-0.5 text-[11px] font-semibold {isExempt ? 'bg-slate-100 text-slate-600 border border-slate-200' : 'bg-teal-50 text-teal-700 border border-teal-200'}">
      {ratePercent}
    </span>
  </div>
</div>
