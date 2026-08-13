<script>
  export let title = "Confirm action"
  export let message = ""
  export let confirmLabel = "Confirm"
  export let danger = false
  export let oncancel = () => {}
  export let onconfirm = () => {}
</script>

<svelte:window onkeydown={(event) => event.key === "Escape" && oncancel()} />

<div class="modal-scrim" role="presentation" onclick={(event) => event.currentTarget === event.target && oncancel()}>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="confirm-title" tabindex="-1">
    <div class="modal-body">
      <h2 id="confirm-title" class="modal-title">{title}</h2>
      <p class="modal-text">{message}</p>
    </div>
    <footer class="modal-foot">
      <button class="k-btn k-btn-sm" type="button" onclick={oncancel}>Keep editing <kbd>Esc</kbd></button>
      <button class={`k-btn k-btn-sm ${danger ? "k-btn-danger-solid" : "k-btn-primary"}`} type="button" onclick={onconfirm}>{confirmLabel}</button>
    </footer>
  </div>
</div>
