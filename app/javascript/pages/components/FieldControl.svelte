<script>
  import { machineField } from "../../lib/design-system.js"

  export let field
  export let value
  export let onvalue = () => {}

  $: wide = ["textarea", "file", "multiselect"].includes(field.type)
  $: dataInput = machineField(field.key, field.label) || ["number", "date", "datetime_local"].includes(field.type)
</script>

<div class:field-wide={wide} class="k-field">
  {#if field.type === "checkbox"}
    <label class="k-check">
      <input type="checkbox" checked={Boolean(value)} onchange={(event) => onvalue(event.currentTarget.checked)} />
      <span>{field.label}</span>
    </label>
  {:else}
    <label class="k-label" for={field.key}>{field.label}{#if field.required} <span class="k-req">*</span>{/if}</label>
    {#if field.type === "textarea"}
      <textarea id={field.key} class="k-input" rows="5" required={field.required} value={value || ""} oninput={(event) => onvalue(event.currentTarget.value)}></textarea>
    {:else if field.type === "select"}
      <select id={field.key} class="k-input" required={field.required} value={value ?? ""} onchange={(event) => onvalue(event.currentTarget.value)}>
        <option value="">None</option>
        {#each field.options || [] as option}<option value={option.value}>{option.label}</option>{/each}
      </select>
    {:else if field.type === "multiselect"}
      <select id={field.key} class="k-input" size="6" multiple value={value || []} onchange={(event) => onvalue(Array.from(event.currentTarget.selectedOptions).map((option) => option.value))}>
        {#each field.options || [] as option}<option value={option.value}>{option.label}</option>{/each}
      </select>
      <p class="k-hint">Hold Command or Control to choose more than one.</p>
    {:else if field.type === "file"}
      <input id={field.key} class="k-input" type="file" multiple={field.multiple} accept={field.accept} onchange={(event) => onvalue(field.multiple ? Array.from(event.currentTarget.files || []) : event.currentTarget.files?.[0])} />
    {:else}
      <input id={field.key} class:k-input-data={dataInput} class="k-input" type={field.type === "datetime_local" ? "datetime-local" : field.type} required={field.required} min={field.min} step={field.step} value={value ?? ""} oninput={(event) => onvalue(event.currentTarget.value)} />
    {/if}
  {/if}
</div>
