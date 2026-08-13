<script>
  import { Link, router, usePage } from "@inertiajs/svelte"
  import ConfirmModal from "./ConfirmModal.svelte"
  import FieldControl from "./FieldControl.svelte"
  import PanelHeader from "./PanelHeader.svelte"

  export let form

  const page = usePage()
  let values = Object.fromEntries((form.fields || []).map((field) => [field.key, field.value ?? (field.type === "checkbox" ? false : field.type === "multiselect" ? [] : "")]))
  let processing = false
  let showRemove = false
  $: sharedErrors = page.props.errors || {}
  $: errors = [...(form.errors || []), ...Object.values(sharedErrors).flat()]

  function setValue(key, value) { values = { ...values, [key]: value } }
  function submit(event) {
    event.preventDefault()
    processing = true
    const payload = form.root ? { [form.root]: values } : values
    router[form.method](form.action, payload, { forceFormData: form.fields.some((field) => field.type === "file"), onFinish: () => (processing = false) })
  }
  function remove() { showRemove = false; router.delete(form.delete_path) }
</script>

<section class="screen">
  {#if errors.length}<div class="n-bar n-bad"><span><strong>{errors.length} {errors.length === 1 ? "field needs" : "fields need"} attention.</strong> {errors.join(" · ")}</span></div>{/if}
  <form id="resource-form" class="p-region" onsubmit={submit}>
    <PanelHeader title="Record fields" count={`${form.fields.length} fields`}><Link href={form.cancel} class="k-btn k-btn-xs k-btn-quiet">Discard changes <kbd>Esc</kbd></Link></PanelHeader>
    <div class="screen-scroll"><div class="form-grid">{#each form.fields as field}<FieldControl {field} value={values[field.key]} onvalue={(value) => setValue(field.key, value)} />{/each}</div></div>
    <footer class="form-actions">
      {#if form.delete_path}<button class="k-btn k-btn-sm k-btn-danger" type="button" onclick={() => (showRemove = true)}>Remove record</button>{:else}<span class="faint">Required fields are marked with an asterisk.</span>{/if}
      <span class="faint">{processing ? "Saving changes…" : "Save from the command bar or press Command-S."}</span>
    </footer>
  </form>
</section>

{#if showRemove}<ConfirmModal title="Remove this record?" message="This record will be removed from active use. This cannot be undone." confirmLabel="Remove record" danger oncancel={() => (showRemove = false)} onconfirm={remove} />{/if}
