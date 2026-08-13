<script>
  import { Link } from "@inertiajs/svelte"

  export let pagination
  export let path
  export let query = {}

  $: visiblePages = pageWindow(pagination.page, pagination.pages)

  function pageWindow(current, total) {
    if (total <= 7) return Array.from({ length: total }, (_, index) => index + 1)

    const start = Math.max(2, Math.min(current - 1, total - 4))
    const end = Math.min(total - 1, Math.max(current + 1, 5))
    return [1, ...(start > 2 ? [null] : []), ...Array.from({ length: end - start + 1 }, (_, index) => start + index), ...(end < total - 1 ? [null] : []), total]
  }

  function pageHref(page) {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries({ ...query, page })) {
      if (Array.isArray(value)) value.forEach((item) => params.append(`${key}[]`, item))
      else if (value !== null && value !== undefined && value !== "") params.set(key, value)
    }
    return `${path}?${params.toString()}`
  }
</script>

{#if pagination}
  <footer class="p-foot" data-testid="pagination">
    <span>Rows <strong>{pagination.from || 0}–{pagination.to || 0}</strong> of <strong>{pagination.count}</strong></span>
    {#if pagination.pages > 1}
      <nav class="push row" aria-label="Pagination">
        {#if pagination.previous}<Link href={pageHref(pagination.previous)} class="k-btn k-btn-xs" aria-label="Previous page">Previous</Link>{/if}
        {#each visiblePages as page, index (`${page ?? "gap"}-${index}`)}
          {#if page === null}
            <span class="data faint" aria-hidden="true">…</span>
          {:else if page === pagination.page}
            <span class="k-btn k-btn-xs k-btn-primary" aria-current="page">{page}</span>
          {:else}
            <Link href={pageHref(page)} class="k-btn k-btn-xs" aria-label={`Page ${page}`}>{page}</Link>
          {/if}
        {/each}
        {#if pagination.next}<Link href={pageHref(pagination.next)} class="k-btn k-btn-xs" aria-label="Next page">Next</Link>{/if}
      </nav>
    {/if}
  </footer>
{/if}
