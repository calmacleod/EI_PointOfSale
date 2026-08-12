<script>
  import { Link, router } from "@inertiajs/svelte"
  export let title
  export let description
  export let form
  export let secondary = null

  let values = Object.fromEntries((form?.fields || []).map((field) => [field.key, field.value ?? ""]))

  function submit(event) {
    event.preventDefault()
    const method = form.method || "post"
    router[method](form.action, form.root ? { [form.root]: values } : values)
  }
</script>

<section class="ui-card p-5 sm:p-6">
  <div class="mb-5 flex items-center gap-3">
    <span class="flex size-10 items-center justify-center rounded-lg font-bold" style="background:var(--primary);color:var(--primary-foreground)">EI</span>
    <div><p class="text-sm font-semibold">EI Point of Sale</p><p class="text-xs" style="color:var(--muted)">Store operations</p></div>
  </div>
  <h1 class="text-2xl font-semibold">{title}</h1>
  <p class="mt-1 text-sm" style="color:var(--muted)">{description}</p>

  <form class="mt-6 space-y-4" onsubmit={submit}>
    {#each form.fields as field}
      <div>
        <label class="ui-label" for={field.key}>{field.label}</label>
        <input class="ui-input" id={field.key} type={field.type} required={field.required} autocomplete={field.autocomplete || "off"} bind:value={values[field.key]} />
      </div>
    {/each}
    <button class="ui-button ui-button-primary w-full" type="submit">{form.submit_label}</button>
  </form>
  {#if secondary}<Link href={secondary.path} class="mt-3 block text-center text-sm font-medium" style="color:var(--primary)">{secondary.label}</Link>{/if}
</section>
