<script>
  let { onSearch } = $props()

  let query = $state("")
  let timer

  function handleInput(e) {
    query = e.target.value
    clearTimeout(timer)
    timer = setTimeout(() => onSearch(query), 200)
  }

  function handleKeydown(e) {
    if (e.key === "Escape") {
      query = ""
      onSearch("")
    }
  }
</script>

<div class="relative">
  <div class="pointer-events-none absolute inset-y-0 left-3 flex items-center">
    <svg class="h-4 w-4 text-[var(--sidebar-text)] opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
  </div>
  <input
    type="search"
    placeholder="Search by name or code…"
    value={query}
    oninput={handleInput}
    onkeydown={handleKeydown}
    class="w-full rounded-lg border border-white/10 bg-white/5 py-2.5 pl-9 pr-4 text-sm text-[var(--sidebar-text-bright)] placeholder-[var(--sidebar-text)] outline-none transition focus:border-white/20 focus:bg-white/10 focus:ring-0"
    autofocus
  />
  {#if query}
    <button
      onclick={() => { query = ""; onSearch("") }}
      class="absolute inset-y-0 right-3 flex items-center text-[var(--sidebar-text)] opacity-50 hover:opacity-100"
    >
      <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  {/if}
</div>
