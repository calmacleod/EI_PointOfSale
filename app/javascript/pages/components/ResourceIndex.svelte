<script>
  import { Link, router } from "@inertiajs/svelte"
  import EmptyState from "./EmptyState.svelte"
  import PanelHeader from "./PanelHeader.svelte"
  import StatusTag from "./StatusTag.svelte"
  import { displayValue, machineField, numericField, rowTone } from "../../lib/design-system.js"

  export let title
  export let columns = []
  export let rows = []
  export let filters = []
  export let query = {}
  export let pagination = null
  export let actions = {}
  export let empty_message = "No records found."
  export let templates = []

  let values = { ...query }
  let showFilters = false
  $: activeFilters = Object.entries(values).filter(([key, value]) => !["q", "sort", "dir", "page"].includes(key) && value !== "" && value !== null && value !== undefined && (!Array.isArray(value) || value.length))

  function updateValue(key, value) { values = { ...values, [key]: value } }
  function submit(event) { event.preventDefault(); router.get(actions.index, values, { preserveState: true, replace: true }) }
  function clearFilters() { values = {}; router.get(actions.index, {}, { replace: true }) }
  function removeFilter(key) { const next = { ...values }; delete next[key]; values = next; router.get(actions.index, next, { preserveState: true, replace: true }) }
  function sort(column) {
    if (!column.sortable) return
    const direction = values.sort === column.key && values.dir === "asc" ? "desc" : "asc"
    values = { ...values, sort: column.key, dir: direction }
    router.get(actions.index, values, { preserveState: true, replace: true })
  }
  function pageHref(page) {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries({ ...values, page })) {
      if (Array.isArray(value)) value.forEach((item) => params.append(`${key}[]`, item))
      else if (value !== null && value !== undefined && value !== "") params.set(key, value)
    }
    return `${actions.index}?${params.toString()}`
  }
  function statusColumn(column) { return /(status|state|active)/i.test(`${column.key} ${column.label}`) }
</script>

<section class="screen">
  {#if templates.length}
    <section class="p-region" style="flex:none">
      <PanelHeader title="Report templates" count={templates.length} />
      <div class="console-grid" style="grid-template-columns:repeat(3,minmax(0,1fr))">
        {#each templates as template}<Link href={template.path} class="list-row"><span class="grow col"><strong>{template.title}</strong><span class="faint">{template.description}</span></span><span class="data">→</span></Link>{/each}
      </div>
    </section>
  {/if}

  <form onsubmit={submit}>
    <div class="f-bar">
      <span class="p-title">Filter</span>
      <div style="position:relative;flex:1;min-width:200px;max-width:340px">
        <input id="resource-search" class="k-input k-input-sm" style="width:100%" type="search" placeholder="Filter this list…" value={values.q || ""} oninput={(event) => updateValue("q", event.currentTarget.value)} />
      </div>
      {#if filters.length}<button class="k-btn k-btn-sm k-btn-quiet" type="button" aria-expanded={showFilters} onclick={() => showFilters = !showFilters}>{showFilters ? "Hide filters" : "Add filter"}</button>{/if}
      {#each activeFilters as [key, value]}<span class="f-chip"><span class="f-chip-key">{key.replaceAll("_", " ")}</span>{Array.isArray(value) ? value.join(", ") : value}<button class="f-chip-x" type="button" aria-label={`Remove ${key} filter`} onclick={() => removeFilter(key)}>×</button></span>{/each}
      <span class="push row">
        {#if activeFilters.length || values.q}<button class="k-btn k-btn-xs k-btn-quiet" type="button" onclick={clearFilters}>Clear all</button>{/if}
        <button class="k-btn k-btn-sm" type="submit">Apply <kbd>↵</kbd></button>
      </span>
    </div>

    {#if showFilters}
      <div class="f-builder">
        {#each filters as filter}
          {#if ["association", "select", "boolean"].includes(filter.type)}
            <label class="col"><span class="k-label">{filter.label}</span><select class="k-input k-input-sm" value={values[filter.key] || ""} onchange={(event) => updateValue(filter.key, event.currentTarget.value)}><option value="">All</option>{#each filter.choices || [] as choice}<option value={choice.value}>{choice.label}</option>{/each}</select></label>
          {:else if filter.type === "multi_select"}
            <label class="col"><span class="k-label">{filter.label}</span><select class="k-input f-multi" multiple value={values[filter.key] || []} onchange={(event) => updateValue(filter.key, Array.from(event.currentTarget.selectedOptions).map((option) => option.value))}>{#each filter.choices || [] as choice}<option value={choice.value}>{choice.label}</option>{/each}</select></label>
          {:else if filter.type === "number_range"}
            <span class="col"><span class="k-label">{filter.label}</span><span class="row"><input class="k-input k-input-sm k-input-data grow" type="number" aria-label={`${filter.label} minimum`} placeholder="Minimum" value={values[`${filter.key}_min`] || ""} oninput={(event) => updateValue(`${filter.key}_min`, event.currentTarget.value)} /><input class="k-input k-input-sm k-input-data grow" type="number" aria-label={`${filter.label} maximum`} placeholder="Maximum" value={values[`${filter.key}_max`] || ""} oninput={(event) => updateValue(`${filter.key}_max`, event.currentTarget.value)} /></span></span>
          {:else if filter.type === "date_range"}
            <span class="col"><span class="k-label">{filter.label}</span><span class="row"><input class="k-input k-input-sm k-input-data grow" type="date" aria-label={`${filter.label} from`} value={values[`${filter.key}_from`] || ""} oninput={(event) => updateValue(`${filter.key}_from`, event.currentTarget.value)} /><input class="k-input k-input-sm k-input-data grow" type="date" aria-label={`${filter.label} to`} value={values[`${filter.key}_to`] || ""} oninput={(event) => updateValue(`${filter.key}_to`, event.currentTarget.value)} /></span></span>
          {/if}
        {/each}
        <div class="row" style="align-self:end"><button class="k-btn k-btn-sm k-btn-primary" type="submit">Apply filters</button></div>
      </div>
    {/if}
  </form>

  <section class="p-region" id={`${title.toLowerCase().replaceAll(" ", "_")}_table`}>
    <PanelHeader title={title} count={pagination ? `${pagination.count} records` : `${rows.length} records`} />
    <div class="t-wrap">
      <table class="t" style="min-width:900px">
        <thead><tr>{#each columns as column}<th class:r={numericField(column.key, column.label)} aria-sort={column.sortable && values.sort === column.key ? (values.dir === "asc" ? "ascending" : "descending") : undefined}><button class="t-sort" type="button" onclick={() => sort(column)}>{column.label}{#if column.sortable && values.sort === column.key} {values.dir === "asc" ? "↑" : "↓"}{/if}</button></th>{/each}<th class="r">Actions</th></tr></thead>
        <tbody>
          {#each rows as row}
            <tr data-state={rowTone(row)}>
              {#each columns as column}
                <td class:data={machineField(column.key, column.label)} class:r={numericField(column.key, column.label)} class:wrap={column === columns[0]}>
                  {#if column === columns[0] && row.show_path}<Link href={row.show_path}>{displayValue(row.values[column.key])}</Link>
                  {:else if statusColumn(column)}<StatusTag value={displayValue(row.values[column.key])} />
                  {:else}{displayValue(row.values[column.key])}{/if}
                </td>
              {/each}
              <td class="r">{#if row.edit_path}<Link href={row.edit_path} class="k-btn k-btn-xs k-btn-quiet">Edit</Link>{/if}</td>
            </tr>
          {:else}
            <tr><td colspan={columns.length + 1}><EmptyState title="No matching records" body={empty_message} /></td></tr>
          {/each}
        </tbody>
      </table>
    </div>
    {#if pagination}
      <footer class="p-foot"><span>Rows <strong>{rows.length}</strong> of <strong>{pagination.count}</strong> · page {pagination.page} of {pagination.pages}</span><div class="push row">{#if pagination.previous}<Link href={pageHref(pagination.previous)} class="k-btn k-btn-xs">Previous</Link>{/if}{#if pagination.next}<Link href={pageHref(pagination.next)} class="k-btn k-btn-xs">Next</Link>{/if}</div></footer>
    {/if}
  </section>
</section>
