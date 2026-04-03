<script>
  let { activePage = "products", onNavigate } = $props()

  const navItems = [
    {
      id: "products",
      label: "Product Lookup",
      icon: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z",
    },
    {
      id: "services",
      label: "Services",
      icon: "M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
    },
    {
      id: "tax_codes",
      label: "Tax Codes",
      icon: "M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z",
    },
  ]
</script>

<aside class="flex w-56 shrink-0 flex-col overflow-hidden border-r border-[#dcdce0] bg-[#f5f5f7]">
  <!-- Brand -->
  <div class="flex items-center gap-2.5 border-b border-[#dcdce0] px-3 py-2.5">
    <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-[#0d9488] text-[10px] font-bold text-white select-none">EI</div>
    <div class="min-w-0 flex-1">
      <p class="truncate text-[13px] font-semibold leading-tight text-[#1a1a2e]">Point of Sale</p>
      <p class="truncate text-[11px] leading-tight text-[#8e8e9a]">Offline Mode</p>
    </div>
  </div>

  <!-- Offline notice -->
  <div class="border-b border-[#dcdce0] px-3 py-3">
    <div class="rounded-md border border-amber-200 bg-amber-50 px-3 py-2.5">
      <div class="flex items-start gap-2">
        <svg class="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636a9 9 0 010 12.728M15.536 8.464a5 5 0 010 7.072M6 18L18 6M8.464 15.536a5 5 0 010-7.072M5.636 18.364a9 9 0 010-12.728"/>
        </svg>
        <div>
          <p class="text-[12px] font-semibold text-amber-800">App is offline</p>
          <p class="mt-0.5 text-[11px] leading-snug text-amber-700">Limited features available. Data lookup works with locally cached data.</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Navigation -->
  <nav class="flex-1 overflow-y-auto px-2.5 py-2">
    <p class="mb-1 px-2 text-[10px] font-semibold uppercase tracking-wider text-[#8e8e9a]">Available offline</p>

    {#each navItems as item}
      <button
        onclick={() => onNavigate(item.id)}
        class="flex h-7.5 w-full items-center gap-2.5 rounded-md px-2 text-left text-[13px] font-medium transition-colors
          {activePage === item.id
            ? 'bg-black/7 text-[#1a1a2e]'
            : 'text-[#555566] hover:bg-black/4 hover:text-[#1a1a2e]'}"
      >
        <svg class="h-4 w-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d={item.icon}/>
        </svg>
        <span class="min-w-0 truncate">{item.label}</span>
      </button>
    {/each}

    <p class="mb-1 mt-3 px-2 text-[10px] font-semibold uppercase tracking-wider text-[#8e8e9a]">Requires connection</p>

    {#each [
      { label: "Register", icon: "M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" },
      { label: "Orders", icon: "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" },
      { label: "Customers", icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" },
      { label: "Reports", icon: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" },
    ] as item}
      <div class="flex h-7.5 cursor-not-allowed items-center gap-2.5 rounded-md px-2 text-[13px] font-medium text-[#555566] opacity-35">
        <svg class="h-4 w-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d={item.icon}/>
        </svg>
        <span class="min-w-0 truncate">{item.label}</span>
      </div>
    {/each}
  </nav>

  <!-- Bottom: back link -->
  <div class="shrink-0 border-t border-[#dcdce0] px-2.5 py-2">
    <a
      href="/"
      class="flex h-7.5 items-center gap-2.5 rounded-md px-2 text-[13px] font-medium text-[#555566] hover:bg-black/4 hover:text-[#1a1a2e]"
    >
      <svg class="h-4 w-4 shrink-0 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
      </svg>
      <span class="min-w-0 truncate">Back to POS</span>
    </a>
  </div>
</aside>
