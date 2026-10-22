<script>
  import EmptyState from "./EmptyState.svelte"
  export let rows = []
  export let columns = []
  export let title = "Report details"
  let search = ""
  let page = 1
  let sortKey = ""
  let direction = 1
  const pageSize = 50

  $: filtered = rows.filter((row) => columns.some((column) => String(row[column.key] ?? "").toLocaleLowerCase().includes(search.toLocaleLowerCase())))
  $: sorted = sortKey ? [...filtered].sort((a, b) => compare(a[sortKey], b[sortKey], columns.find((column) => column.key === sortKey)) * direction) : filtered
  $: pageCount = Math.max(1, Math.ceil(sorted.length / pageSize))
  $: currentPage = Math.min(page, pageCount)
  $: visible = sorted.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  function compare(a, b, column) {
    if (["currency", "integer", "percentage"].includes(column?.type)) return Number(String(a ?? 0).replace(/[$,%]/g, "")) - Number(String(b ?? 0).replace(/[$,%]/g, ""))
    if (["date", "datetime"].includes(column?.type)) return (Date.parse(a) || 0) - (Date.parse(b) || 0)
    return String(a ?? "").localeCompare(String(b ?? ""), undefined, { numeric: true })
  }
  function sort(column) { direction = sortKey === column.key ? -direction : 1; sortKey = column.key; page = 1 }
  function format(value, column) {
    if (value === null || value === undefined || value === "") return "—"
    if (column.type === "currency" && !String(value).startsWith("$")) return Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" })
    if (column.type === "integer") return Number(value).toLocaleString()
    if (column.type === "datetime" && /^\d{4}-\d{2}-\d{2}T/.test(value)) return new Date(value).toLocaleString()
    return value
  }
</script>

<section class="report-table" aria-label={title}>
  <div class="table-tools"><h2>{title} <span class="faint">({rows.length.toLocaleString()})</span></h2><label class="table-search"><span class="k-label">Search these rows</span><input class="k-input k-input-sm" type="search" bind:value={search} oninput={() => (page = 1)} /></label></div>
  {#if visible.length}
    <div class="table-scroll"><table class="t"><thead><tr>{#each columns as column}<th scope="col" aria-sort={sortKey === column.key ? (direction === 1 ? "ascending" : "descending") : "none"}><button type="button" onclick={() => sort(column)}>{column.label}{sortKey === column.key ? (direction === 1 ? " ↑" : " ↓") : ""}</button></th>{/each}</tr></thead><tbody>{#each visible as row}<tr>{#each columns as column}<td class:data={["currency", "integer", "percentage"].includes(column.type)}>{format(row[column.key], column)}</td>{/each}</tr>{/each}</tbody></table></div>
    <div class="table-tools"><p class="faint" role="status">{(currentPage - 1) * pageSize + 1}–{Math.min(currentPage * pageSize, sorted.length)} of {sorted.length.toLocaleString()} rows · Download includes all saved rows.</p><div class="row"><button class="k-btn k-btn-sm" type="button" disabled={currentPage === 1} onclick={() => (page = currentPage - 1)}>Previous</button><button class="k-btn k-btn-sm" type="button" disabled={currentPage === pageCount} onclick={() => (page = currentPage + 1)}>Next</button></div></div>
  {:else}<EmptyState title={search ? "No matching rows" : "No records for these settings"} body={search ? "Try a shorter search or clear the search box." : "Try another date range or change the report settings."} />{/if}
</section>

<style>
  .report-table { min-width: 0; }
  .table-tools { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: var(--space-3); padding: var(--space-3) var(--space-4); }
  h2 { font-size: var(--text-data); font-weight: 600; }
  .table-search { display: grid; gap: var(--space-1); }
  .table-scroll { overflow: auto; max-height: 600px; }
  th button { color: inherit; font: inherit; cursor: pointer; text-align: left; }
  td { max-width: 360px; overflow-wrap: anywhere; }
</style>
