<script>
  import { Link, router, usePage } from "@inertiajs/svelte"
  import BrandLockup from "./BrandLockup.svelte"

  export let title
  export let description
  export let form
  export let secondary = null

  const page = usePage()
  let values = Object.fromEntries((form?.fields || []).map((field) => [field.key, field.value ?? ""]))
  let processing = false

  function submit(event) {
    event.preventDefault()
    processing = true
    const method = form.method || "post"
    router[method](form.action, form.root ? { [form.root]: values } : values, { onFinish: () => (processing = false) })
  }
</script>

<div class="auth-shell">
  <section class="auth-brand">
    <BrandLockup variant="stacked" size={32} chrome={true} />
    <div style="margin-top:auto;max-width:46ch">
      <p class="k-label" style="color:var(--chrome-text-faint)">Operator workspace</p>
      <p style="margin-top:var(--space-2);color:var(--chrome-text);font-size:var(--text-data);line-height:var(--leading-normal)">Sales, inventory, customers, drawer reconciliation, and reports stay in one keyboard-driven workspace.</p>
      <div style="margin-top:var(--space-4);border-top:1px solid var(--chrome-border);padding-top:var(--space-3)">
        <span class="c-status-group"><span class="c-dot c-dot-ok"></span>Server connection ready</span>
      </div>
    </div>
  </section>

  <section class="auth-panel">
    <form class="auth-form" onsubmit={submit}>
      <div>
        <h1 style="font-size:var(--text-strong);font-weight:var(--weight-semibold)">{title}</h1>
        <p class="console-prose" style="margin-top:var(--space-1)">{description}</p>
      </div>
      {#each form.fields as field}
        <div class="k-field">
          <label class="k-label" for={field.key}>{field.label}{#if field.required} <span class="k-req">*</span>{/if}</label>
          <input class="k-input" id={field.key} type={field.type} required={field.required} autocomplete={field.autocomplete || "off"} bind:value={values[field.key]} />
        </div>
      {/each}
      <button class="k-btn k-btn-primary k-btn-block" style="height:var(--control-key)" type="submit" disabled={processing}>{processing ? "Signing in…" : form.submit_label} <kbd>↵</kbd></button>
      {#if secondary}<Link href={secondary.path} class="k-btn k-btn-quiet k-btn-block">{secondary.label}</Link>{/if}
      {#if page.props.paths?.offline}
        <div class="row"><span class="p-rule grow"></span><span class="k-label">or</span><span class="p-rule grow"></span></div>
        <a href={page.props.paths.offline} class="k-key">Offline lookup<span class="k-key-sub">Read-only catalogue · F1</span></a>
      {/if}
    </form>
    <footer class="p-foot" style="margin-top:auto"><span>EI Point of Sale</span><span class="push c-status-group"><span class="c-dot c-dot-ok"></span>Server reachable</span></footer>
  </section>
</div>
