<script>
  import { Deferred, Link, router } from "@inertiajs/svelte"
  import { onMount } from "svelte"
  import ConfirmModal from "./ConfirmModal.svelte"
  import ResourceIndex from "./ResourceIndex.svelte"
  import ReportChart from "./ReportChart.svelte"
  import ReportTable from "./ReportTable.svelte"
  import StatusTag from "./StatusTag.svelte"

  export let view
  export let title = ""
  export let description = ""
  export let templates = []
  export let columns = []
  export let rows = []
  export let filters = []
  export let query = {}
  export let pagination = null
  export let can_create = false
  export let actions = {}
  export let form = null
  export let report = null

  let catalogSearch = ""
  let category = "All"
  let values = { ...(form?.values || {}) }
  let reportTitle = form?.title || ""
  let previousForm = form
  let submitting = false
  let deleting = false
  let poll

  $: if (form !== previousForm) { previousForm = form; values = { ...(form?.values || {}) }; reportTitle = form?.title || "" }
  $: categories = ["All", ...new Set(templates.map((template) => template.category))]
  $: matching = templates.filter((template) => (category === "All" || template.category === category) && `${template.title} ${template.description}`.toLocaleLowerCase().includes(catalogSearch.toLocaleLowerCase()))
  $: dataset = form?.datasets?.find((item) => item.key === values.dataset)
  $: hasDates = form?.parameters?.some((parameter) => parameter.key === "start_date") && (!dataset || ["sales", "refunds"].includes(dataset.key))
  $: result = report?.result_data
  $: charts = result?.chart?.datasets ? [["Overview", result.chart]] : Object.entries(result?.chart || {})

  onMount(() => {
    // Only status metadata is polled. The completed dataset remains deferred.
    poll = router.poll(2000, { only: ["report", "actions"], preserveScroll: true }, { autoStart: false })
    return () => poll.stop()
  })
  $: if (poll) {
    if (view === "report_show" && ["pending", "processing"].includes(report?.status)) poll.start()
    else poll.stop()
  }

  function changeDataset(event) {
    const next = form.datasets.find((item) => item.key === event.currentTarget.value)
    values = { ...values, dataset: next.key, columns: next.columns.map((column) => column.key) }
  }
  function submit(event) {
    event.preventDefault()
    if (submitting) return
    submitting = true
    router.post(form.action, { report: { report_type: form.report_type, title: reportTitle, parameters: values } }, { onFinish: () => (submitting = false) })
  }
  function remove() { deleting = false; router.delete(actions.delete) }
</script>

<section class="screen reports-screen">
  <div class="screen-scroll">
    {#if view === "report_library"}
      <header class="report-intro"><p class="eyebrow">Your business, at a glance</p><h1>Report library</h1><p>Start with a ready-made report, or choose your own columns for Excel.</p>{#if !can_create}<p class="k-hint">Open and download saved reports below. Ask an administrator to generate a new report.</p>{/if}</header>
      {#if can_create}
        <div class="catalog-tools"><label class="catalog-search"><span class="k-label">Find a report</span><input class="k-input" type="search" placeholder="Sales, customers, inventory…" bind:value={catalogSearch} /></label><label><span class="k-label">Category</span><select class="k-input" bind:value={category}>{#each categories as item}<option>{item}</option>{/each}</select></label></div>
        <div class="report-catalog">{#each matching as template (template.key)}<Link href={template.path} class={`report-card ${template.key === "custom_export" ? "custom" : ""}`}><span class="eyebrow">{template.category}</span><h2>{template.title}</h2><p>{template.description}</p><strong>{template.key === "custom_export" ? "Choose data and columns" : "Set up report"} →</strong></Link>{:else}<p class="report-intro">No reports match your search.</p>{/each}</div>
      {/if}
      <div class="history-heading"><h2>Saved reports</h2><p class="faint">Saved snapshots keep their original results. Open a report to download it or reuse its settings.</p></div>
      <div class="report-history"><ResourceIndex title="Reports" {columns} {rows} {filters} {query} {pagination} {actions} empty_message="No saved reports match these filters." /></div>
    {:else if view === "report_form"}
      <header class="report-intro"><Link href={actions.index} class="back-link">← Report library</Link><h1>{title}</h1><p>{description}</p></header>
      <form id="report-form" onsubmit={submit} class="report-setup">
        {#if form.errors?.length}<div class="n-bar n-bad" role="alert"><strong>Check your report settings.</strong><ul>{#each form.errors as error}<li>{error}</li>{/each}</ul></div>{/if}
        <div class="setup-section"><h2>Report settings</h2><label><span class="k-label">Report name (optional)</span><input class="k-input" type="text" maxlength="200" placeholder="For example, October sales for my accountant" bind:value={reportTitle} /></label>
          {#if dataset}<label><span class="k-label">Data</span><select class="k-input" value={values.dataset} onchange={changeDataset}>{#each form.datasets as item}<option value={item.key}>{item.label}</option>{/each}</select></label><p class="k-hint">{dataset.description}</p>{/if}
          {#if hasDates}
            <fieldset><legend class="k-label">Choose a date range</legend><div class="date-shortcuts">{#each form.date_presets || [] as preset}<button class="k-btn k-btn-sm" class:k-btn-primary={values.start_date === preset.start_date && values.end_date === preset.end_date} type="button" onclick={() => (values = { ...values, start_date: preset.start_date, end_date: preset.end_date })}>{preset.label}</button>{/each}</div><div class="date-fields">{#each form.parameters.filter((parameter) => parameter.type === "date") as parameter}<label><span class="k-label">{parameter.label}</span><input class="k-input" type="date" required bind:value={values[parameter.key]} max={parameter.key === "start_date" ? values.end_date : undefined} min={parameter.key === "end_date" ? values.start_date : undefined} /></label>{/each}</div></fieldset>
          {/if}
          {#each form.parameters.filter((parameter) => parameter.type === "select" && parameter.key !== "dataset") as parameter}<label><span class="k-label">{parameter.label}</span><select class="k-input" bind:value={values[parameter.key]}>{#each parameter.options || [] as option}<option value={option[1]}>{option[0]}</option>{/each}</select></label>{/each}
        </div>
        {#if dataset}<fieldset class="setup-section"><legend>Columns to include</legend><p class="k-hint">Select the information you need. The columns appear in the order shown.</p><div class="date-shortcuts"><button class="k-btn k-btn-sm" type="button" onclick={() => (values = { ...values, columns: dataset.columns.map((column) => column.key) })}>Select all</button><button class="k-btn k-btn-sm" type="button" onclick={() => (values = { ...values, columns: [] })}>Clear selection</button></div><div class="column-choices">{#each dataset.columns as column}<label class="column-choice"><input type="checkbox" value={column.key} bind:group={values.columns} /><span>{column.label}</span></label>{/each}</div><p class="k-hint" role="status">{values.columns?.length || 0} columns selected.</p></fieldset>{/if}
        <footer class="setup-section"><p class="k-hint">This saves a snapshot you can review, download, and run again. Your original records stay as they are.</p><div class="date-shortcuts"><button class="k-btn k-btn-primary" type="submit" disabled={submitting || (dataset && !values.columns?.length)}>{submitting ? "Starting report…" : "Generate report"}</button><Link href={actions.index} class="k-btn">Cancel</Link></div></footer>
      </form>
    {:else if view === "report_show"}
      <header class="report-intro"><Link href={actions.index} class="back-link">← Report library</Link><h1>{title}</h1><p>{description}</p><div class="report-toolbar"><StatusTag value={report.status} /><span class="faint">{report.completed_at ? `Generated ${report.completed_at}` : `Requested ${report.created_at}`} · {report.generated_by}</span></div><div class="report-toolbar">{#if actions.excel}<a href={actions.excel} class="k-btn k-btn-primary">Download Excel</a>{/if}{#if actions.pdf}<a href={actions.pdf} class="k-btn">Download PDF</a>{/if}{#if actions.rerun}<Link href={actions.rerun} class="k-btn">Change settings / run again</Link>{/if}</div></header>
      {#if ["pending", "processing"].includes(report.status)}<div class="report-intro" role="status" aria-live="polite"><h2>{report.status === "pending" ? "Your report is queued" : "Your report is being prepared"}</h2><p>This page checks automatically. You can keep working and open the report from Saved reports later.</p></div>
      {:else if report.status === "failed"}<div class="report-intro" role="alert"><h2>The report could not be generated</h2><p>Use “Change settings / run again” to try another date range or retry.</p><details><summary>Technical details</summary><p>{report.error_message}</p></details></div>
      {:else if report.status === "completed"}
        <Deferred data="report.result_data">
          {#snippet fallback()}<p class="report-intro" aria-busy="true">Loading your report…</p>{/snippet}
          {#snippet rescue()}<div class="report-intro" role="alert"><p>Results could not be loaded.</p><button class="k-btn" type="button" onclick={() => router.reload()}>Try again</button></div>{/snippet}
          {#if result}
            {#if result.summary?.date_range || result.summary?.notes || result.summary?.table_note}<div class="report-result-notes">{#if result.summary.date_range}<p><strong>Date range:</strong> {result.summary.date_range}</p>{/if}{#if result.summary.notes}<p>{result.summary.notes}</p>{/if}{#if result.summary.table_note}<p role="note">{result.summary.table_note}. Run this report again to generate a new result with all detail rows.</p>{/if}</div>{/if}
            <dl class="report-summary">{#each Object.entries(result.summary || {}).filter(([key]) => !["notes", "date_range", "table_note"].includes(key)) as [key, value]}<div><dt>{key.replaceAll("_", " ")}</dt><dd>{value}</dd></div>{/each}</dl>
            {#each charts as [name, chart]}{#if chart.labels?.length && chart.datasets?.length}<ReportChart data={chart} type={report.chart_type || "bar"} title={name.replaceAll("_", " ")} />{/if}{/each}
            <ReportTable columns={result.columns || report.table_columns} rows={result.table || []} />
            {#if result.held_orders_table?.length}<ReportTable title="Held orders (excluded from totals)" columns={result.columns || report.table_columns} rows={result.held_orders_table} />{/if}
            {#each result.additional_tables || [] as table}<ReportTable title={table.name} columns={table.columns} rows={table.rows} />{/each}
          {/if}
        </Deferred>
      {/if}
      <div class="report-intro report-settings"><details><summary>Report settings and snapshot details</summary><p class="k-hint">These results reflect the data when the report was generated. New activity is included when you run it again.</p><dl>{#each Object.entries(report.parameters || {}) as [key, value]}<div><dt>{key.replaceAll("_", " ")}</dt><dd>{Array.isArray(value) ? value.join(", ") : value || "All"}</dd></div>{/each}</dl></details>{#if actions.delete}<button class="k-btn k-btn-danger" type="button" onclick={() => (deleting = true)}>Delete saved report</button>{/if}</div>
    {/if}
  </div>
</section>
{#if deleting}<ConfirmModal title="Delete this saved report?" message="The saved result will be removed. Sales, inventory, and downloaded files are kept." confirmLabel="Delete report" danger oncancel={() => (deleting = false)} onconfirm={remove} />{/if}

<style>
  .reports-screen { color: var(--color-text); }
  .report-intro, .history-heading { padding: var(--space-4) var(--space-6); border-bottom: 1px solid var(--color-border); }
  h1 { font-size: 24px; font-weight: 650; overflow-wrap: anywhere; margin: var(--space-2) 0; line-height: 1.3; }
  h2 { font-size: 16px; font-weight: 600; }
  p { line-height: 1.6; }
  .eyebrow { color: var(--color-accent); text-transform: uppercase; font-size: var(--text-meta); letter-spacing: .08em; }
  .reports-screen :global(.back-link) { font-size: var(--text-data); color: var(--color-text-muted); }
  .catalog-tools { display: flex; flex-wrap: wrap; gap: var(--space-3); padding: var(--space-4) var(--space-6); }
  .catalog-search { flex: 1; max-width: 400px; }
  label { display: grid; gap: var(--space-2); }
  .report-catalog { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: var(--space-3); padding: 0 var(--space-6) var(--space-6); }
  .reports-screen :global(.report-card) { display: flex; flex-direction: column; gap: var(--space-2); padding: var(--space-4); border: 1px solid var(--color-border); border-radius: var(--radius-md); color: inherit; text-decoration: none; }
  .reports-screen :global(.report-card:hover) { border-color: var(--color-accent); background: var(--color-surface-alt); }
  .reports-screen :global(.report-card p) { color: var(--color-text-muted); font-size: var(--text-data); flex: 1; }
  .reports-screen :global(.report-card strong) { color: var(--color-accent); font-size: var(--text-data); }
  .reports-screen :global(.report-card.custom) { border-color: var(--color-accent); background: var(--color-surface-alt); }
  .report-history { height: 460px; display: flex; min-width: 0; }
  .report-setup { max-width: 920px; padding: var(--space-4) var(--space-6); }
  .setup-section { display: grid; gap: var(--space-4); padding: var(--space-4) 0; }
  legend { font-weight: 600; }
  .date-shortcuts, .report-toolbar { display: flex; flex-wrap: wrap; gap: var(--space-2); align-items: center; }
  .date-fields { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-4); margin-top: var(--space-3); }
  .column-choices { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: var(--space-3); }
  .column-choice { display: flex; gap: var(--space-2); align-items: center; font-size: var(--text-data); }
  .report-toolbar { margin-top: var(--space-3); }
  .report-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); border-bottom: 1px solid var(--color-border); }
  .report-result-notes { padding: var(--space-3) var(--space-6); background: var(--color-surface-alt); font-size: var(--text-data); }
  .report-summary div { padding: var(--space-4); border: 1px solid var(--color-border); }
  .report-summary dt, .report-settings dt { text-transform: capitalize; color: var(--color-text-muted); font-size: var(--text-meta); }
  .report-summary dd { margin-top: var(--space-1); font-size: 18px; font-weight: 600; overflow-wrap: anywhere; }
  .report-settings { display: grid; gap: var(--space-4); justify-items: start; }
  .report-settings dl { display: grid; gap: var(--space-2); padding-top: var(--space-3); overflow-wrap: anywhere; }
  summary { cursor: pointer; }
  @media (max-width: 700px) {
    .report-intro, .history-heading, .catalog-tools, .report-setup { padding: var(--space-4); }
    .report-catalog { grid-template-columns: minmax(0, 1fr); padding: 0 var(--space-4) var(--space-4); }
    .date-fields { grid-template-columns: minmax(0, 1fr); }
    .report-history { height: 500px; }
  }
</style>
