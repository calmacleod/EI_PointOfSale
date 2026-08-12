<script>
  import { Link, router } from "@inertiajs/svelte"
  import PageHeader from "./PageHeader.svelte"
  export let title
  export let description
  export let columns = []
  export let rows = []
  export let filters = []
  export let query = {}
  export let pagination = null
  export let actions = {}
  export let can_create = false
  export let empty_message = "No records found."
  export let templates = []

  let values = { ...query }

  function updateValue(key, value) { values = { ...values, [key]: value } }
  function submit(event) { event.preventDefault(); router.get(actions.index, values, { preserveState: true, replace: true }) }
  function clearFilters() { values = {}; router.get(actions.index, {}, { replace: true }) }
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
</script>

<PageHeader {title} {description}>{#if can_create && actions.new}<Link href={actions.new} class="ui-button ui-button-primary">New {title.toLowerCase().replace(/s$/, "")}</Link>{/if}</PageHeader>

{#if templates.length}
  <section class="ui-card mb-4 p-4"><h2 class="text-sm font-semibold">New report</h2><p class="mt-1 text-xs" style="color:var(--muted)">Choose a template to start a report.</p><div class="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">{#each templates as template}<Link href={template.path} class="rounded-lg border p-3 hover:shadow-sm" style="border-color:var(--border)"><h3 class="text-sm font-semibold">{template.title}</h3><p class="mt-1 text-xs" style="color:var(--muted)">{template.description}</p></Link>{/each}</div></section>
{/if}

<form class="ui-card mb-3 p-3" onsubmit={submit}>
  <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
    <div><label class="ui-label" for="search">Search</label><input id="search" class="ui-input" type="search" placeholder={`Search ${title.toLowerCase()}…`} value={values.q || ""} oninput={(event) => updateValue("q", event.currentTarget.value)} /></div>
    {#each filters as filter}
      {#if ["association", "select", "boolean"].includes(filter.type)}
        <div><label class="ui-label" for={filter.key}>{filter.label}</label><select id={filter.key} class="ui-input" value={values[filter.key] || ""} onchange={(event) => updateValue(filter.key, event.currentTarget.value)}><option value="">All</option>{#each filter.choices || [] as choice}<option value={choice.value}>{choice.label}</option>{/each}</select></div>
      {:else if filter.type === "multi_select"}
        <div><label class="ui-label" for={filter.key}>{filter.label}</label><select id={filter.key} class="ui-input" multiple value={values[filter.key] || []} onchange={(event) => updateValue(filter.key, Array.from(event.currentTarget.selectedOptions).map((option) => option.value))}>{#each filter.choices || [] as choice}<option value={choice.value}>{choice.label}</option>{/each}</select></div>
      {:else if filter.type === "number_range"}
        <div><div class="ui-label">{filter.label}</div><div class="grid grid-cols-2 gap-1"><input class="ui-input" type="number" aria-label={`${filter.label} minimum`} placeholder="Min" value={values[`${filter.key}_min`] || ""} oninput={(event) => updateValue(`${filter.key}_min`, event.currentTarget.value)} /><input class="ui-input" type="number" aria-label={`${filter.label} maximum`} placeholder="Max" value={values[`${filter.key}_max`] || ""} oninput={(event) => updateValue(`${filter.key}_max`, event.currentTarget.value)} /></div></div>
      {:else if filter.type === "date_range"}
        <div><div class="ui-label">{filter.label}</div><div class="grid grid-cols-2 gap-1"><input class="ui-input" type="date" aria-label={`${filter.label} from`} value={values[`${filter.key}_from`] || ""} oninput={(event) => updateValue(`${filter.key}_from`, event.currentTarget.value)} /><input class="ui-input" type="date" aria-label={`${filter.label} to`} value={values[`${filter.key}_to`] || ""} oninput={(event) => updateValue(`${filter.key}_to`, event.currentTarget.value)} /></div></div>
      {/if}
    {/each}
  </div>
  <div class="mt-3 flex justify-end gap-2"><button class="ui-button ui-button-secondary" type="button" onclick={clearFilters}>Clear</button><button class="ui-button ui-button-primary" type="submit">Apply filters</button></div>
</form>

<section class="ui-card overflow-hidden" id={`${title.toLowerCase().replaceAll(" ", "_")}_table`}>
  <div class="overflow-x-auto"><table class="ui-table"><thead><tr>{#each columns as column}<th><button class="flex items-center gap-1 text-left" type="button" onclick={() => sort(column)}>{column.label}{#if column.sortable && values.sort === column.key}<span>{values.dir === "asc" ? "↑" : "↓"}</span>{/if}</button></th>{/each}<th class="w-20">Actions</th></tr></thead><tbody>
    {#each rows as row}<tr>{#each columns as column}<td>{#if column === columns[0] && row.show_path}<Link href={row.show_path} class="font-semibold" style="color:var(--primary)">{row.values[column.key]}</Link>{:else}{row.values[column.key]}{/if}</td>{/each}<td>{#if row.edit_path}<Link href={row.edit_path} class="text-xs font-semibold" style="color:var(--primary)">Edit</Link>{/if}</td></tr>{:else}<tr><td colspan={columns.length + 1} class="py-8 text-center" style="color:var(--muted)">{empty_message}</td></tr>{/each}
  </tbody></table></div>
  {#if pagination && pagination.pages > 1}<footer class="flex items-center justify-between border-t px-3 py-2 text-xs" style="border-color:var(--border);color:var(--muted)"><span>{pagination.count} records · page {pagination.page} of {pagination.pages}</span><div class="flex gap-2">{#if pagination.previous}<Link href={pageHref(pagination.previous)} class="ui-button ui-button-secondary min-h-8!">Previous</Link>{/if}{#if pagination.next}<Link href={pageHref(pagination.next)} class="ui-button ui-button-secondary min-h-8!">Next</Link>{/if}</div></footer>{/if}
</section>
