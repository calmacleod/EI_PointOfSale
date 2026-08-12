<script>
  import { Link, router, usePage } from "@inertiajs/svelte"
  import PageHeader from "./PageHeader.svelte"
  export let title
  export let description
  export let form

  const page = usePage()
  let values = Object.fromEntries((form.fields || []).map((field) => [field.key, field.value ?? (field.type === "checkbox" ? false : field.type === "multiselect" ? [] : "")]))
  let processing = false
  $: sharedErrors = page.props.errors || {}
  $: errors = [...(form.errors || []), ...Object.values(sharedErrors).flat()]

  function setValue(key, value) { values = { ...values, [key]: value } }
  function submit(event) {
    event.preventDefault()
    processing = true
    const payload = form.root ? { [form.root]: values } : values
    router[form.method](form.action, payload, { forceFormData: form.fields.some((field) => field.type === "file"), onFinish: () => (processing = false) })
  }
  function remove() { if (window.confirm("Remove this record?")) router.delete(form.delete_path) }
</script>

<PageHeader {title} {description}><Link href={form.cancel} class="ui-button ui-button-secondary">Cancel</Link></PageHeader>
<section class="ui-card overflow-hidden">
  {#if errors.length}<div class="border-b border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900"><p class="font-semibold">Please fix the following:</p><ul class="mt-1 list-disc pl-5">{#each errors as error}<li>{error}</li>{/each}</ul></div>{/if}
  <form onsubmit={submit}>
    <div class="grid gap-4 p-4 sm:grid-cols-2 xl:grid-cols-3">
      {#each form.fields as field}
        <div class:sm:col-span-2={field.type === "textarea" || field.type === "file"} class:xl:col-span-3={field.type === "textarea" || field.type === "file"}>
          {#if field.type === "checkbox"}
            <label class="flex min-h-10 items-center gap-2 rounded-lg border px-3 text-sm font-medium" style="border-color:var(--border)"><input type="checkbox" checked={Boolean(values[field.key])} onchange={(event) => setValue(field.key, event.currentTarget.checked)} />{field.label}</label>
          {:else}
            <label class="ui-label" for={field.key}>{field.label}{#if field.required} <span style="color:var(--danger)">*</span>{/if}</label>
            {#if field.type === "textarea"}<textarea id={field.key} class="ui-input min-h-24" required={field.required} value={values[field.key] || ""} oninput={(event) => setValue(field.key, event.currentTarget.value)}></textarea>
            {:else if field.type === "select"}<select id={field.key} class="ui-input" required={field.required} value={values[field.key] ?? ""} onchange={(event) => setValue(field.key, event.currentTarget.value)}><option value="">None</option>{#each field.options || [] as option}<option value={option.value}>{option.label}</option>{/each}</select>
            {:else if field.type === "multiselect"}<select id={field.key} class="ui-input min-h-28" multiple value={values[field.key] || []} onchange={(event) => setValue(field.key, Array.from(event.currentTarget.selectedOptions).map((option) => option.value))}>{#each field.options || [] as option}<option value={option.value}>{option.label}</option>{/each}</select>
            {:else if field.type === "file"}<input id={field.key} class="ui-input" type="file" multiple={field.multiple} accept={field.accept} onchange={(event) => setValue(field.key, field.multiple ? Array.from(event.currentTarget.files || []) : event.currentTarget.files?.[0])} />
            {:else}<input id={field.key} class="ui-input" type={field.type === "datetime_local" ? "datetime-local" : field.type} required={field.required} min={field.min} step={field.step} value={values[field.key] ?? ""} oninput={(event) => setValue(field.key, event.currentTarget.value)} />{/if}
          {/if}
        </div>
      {/each}
    </div>
    <footer class="flex items-center justify-between border-t px-4 py-3" style="border-color:var(--border)">{#if form.delete_path}<button class="ui-button ui-button-danger" type="button" onclick={remove}>Remove</button>{:else}<span></span>{/if}<button class="ui-button ui-button-primary" type="submit" disabled={processing}>{processing ? "Saving…" : form.submit_label}</button></footer>
  </form>
</section>
