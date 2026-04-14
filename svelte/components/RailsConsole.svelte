<script>
  import { onMount, tick } from "svelte"
  import { bootWasm, evalRuby, onWasmProgress } from "../lib/wasm.js"

  let lines = $state([])
  let input = $state("")
  let history = $state([])
  let historyIndex = $state(-1)
  let wasmStatus = $state("idle")
  let wasmProgress = $state("")
  let running = $state(false)
  let inputEl
  let outputEl

  const unsubProgress = onWasmProgress((step) => (wasmProgress = step))

  onMount(async () => {
    wasmStatus = "booting"
    try {
      await bootWasm()
      wasmStatus = "ready"
      pushLine("output", `Rails ${await evalRuby("Rails.version")} — Ruby ${await evalRuby("RUBY_VERSION")} (WASM)`)
      pushLine("output", 'Type Ruby expressions. Try: TaxCode.count')
    } catch (err) {
      wasmStatus = "error"
      pushLine("error", `Boot failed: ${err.message}`)
    }
    return () => unsubProgress()
  })

  function pushLine(type, text) {
    lines = [...lines, { type, text }]
    tick().then(() => outputEl?.scrollTo(0, outputEl.scrollHeight))
  }

  async function run() {
    const code = input.trim()
    if (!code) return

    history = [code, ...history.filter((h) => h !== code)]
    historyIndex = -1
    input = ""

    pushLine("input", code)
    running = true

    try {
      const result = await evalRuby(code)
      pushLine("output", `=> ${result}`)
    } catch (err) {
      pushLine("error", err.message)
    } finally {
      running = false
      await tick()
      inputEl?.focus()
    }
  }

  function onKeydown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      run()
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      historyIndex = Math.min(historyIndex + 1, history.length - 1)
      input = history[historyIndex] ?? ""
    } else if (e.key === "ArrowDown") {
      e.preventDefault()
      historyIndex = Math.max(historyIndex - 1, -1)
      input = historyIndex === -1 ? "" : (history[historyIndex] ?? "")
    }
  }
</script>

<div class="console-page">
  <div class="topbar">
    <div class="topbar-title">
      <svg class="topbar-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75"
          d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
      <h1 class="topbar-heading">Rails Console</h1>
    </div>

    <div class="status-badge"
      class:status-badge--ready={wasmStatus === "ready"}
      class:status-badge--error={wasmStatus === "error"}
      class:status-badge--booting={wasmStatus === "booting"}>
      {#if wasmStatus === "ready"}
        <span class="dot dot--green"></span>WASM ready
      {:else if wasmStatus === "error"}
        <span class="dot dot--red"></span>Error
      {:else}
        <span class="dot dot--yellow dot--pulse"></span>{wasmProgress || "Booting…"}
      {/if}
    </div>
  </div>

  <div class="console-body">
    <div class="output" bind:this={outputEl}>
      {#each lines as line}
        <div class="line line--{line.type}">
          {#if line.type === "input"}
            <span class="prompt">irb&gt;</span>
          {/if}
          <span class="line-text">{line.text}</span>
        </div>
      {/each}
      {#if running}
        <div class="line line--running">
          <span class="prompt">irb&gt;</span>
          <span class="line-text">…</span>
        </div>
      {/if}
    </div>

    <div class="input-row">
      <span class="prompt">irb&gt;</span>
      <textarea
        bind:this={inputEl}
        bind:value={input}
        onkeydown={onKeydown}
        disabled={wasmStatus !== "ready" || running}
        placeholder={wasmStatus === "ready" ? "Enter Ruby expression…" : wasmProgress || "Booting Rails WASM…"}
        rows="1"
        class="input"
        spellcheck="false"
        autocomplete="off"
      ></textarea>
      <button class="run-btn" onclick={run} disabled={wasmStatus !== "ready" || running || !input.trim()}>
        Run
      </button>
    </div>
  </div>
</div>

<style>
  .console-page {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    border-bottom: 1px solid #c8c8c8;
    background: white;
    padding: 10px 16px;
  }

  .topbar-title {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .topbar-icon {
    width: 16px;
    height: 16px;
    color: #0d9488;
    flex-shrink: 0;
  }

  .topbar-heading {
    font-size: 14px;
    font-weight: 600;
    color: #1a1a2e;
    margin: 0;
  }

  /* Status badge */
  .status-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 500;
    border: 1px solid #e5e5e5;
    background: #f5f5f7;
    color: #555566;
  }

  .status-badge--ready { background: #f0fdf4; border-color: #bbf7d0; color: #166534; }
  .status-badge--error { background: #fef2f2; border-color: #fecaca; color: #991b1b; }
  .status-badge--booting { background: #fffbeb; border-color: #fde68a; color: #92400e; }

  .dot {
    display: inline-block;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .dot--green { background: #22c55e; }
  .dot--red { background: #ef4444; }
  .dot--yellow { background: #f59e0b; }
  .dot--pulse { animation: pulse 1.4s ease-in-out infinite; }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  /* Console body */
  .console-body {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    background: #1a1a2e;
    font-family: "Menlo", "Monaco", "Consolas", monospace;
    font-size: 13px;
  }

  .output {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .line {
    display: flex;
    gap: 8px;
    line-height: 1.6;
    word-break: break-all;
  }

  .line--input .line-text { color: #e2e8f0; }
  .line--output .line-text { color: #6ee7b7; }
  .line--error .line-text { color: #fca5a5; }
  .line--running .line-text { color: #94a3b8; }

  .prompt {
    color: #64748b;
    flex-shrink: 0;
    user-select: none;
  }

  .line-text {
    white-space: pre-wrap;
  }

  /* Input row */
  .input-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
    border-top: 1px solid #2d3748;
    padding: 10px 16px;
    background: #1e2535;
  }

  .input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    color: #e2e8f0;
    font-family: inherit;
    font-size: 13px;
    line-height: 1.5;
    resize: none;
    padding: 0;
  }

  .input::placeholder {
    color: #4a5568;
  }

  .input:disabled {
    opacity: 0.5;
  }

  .run-btn {
    flex-shrink: 0;
    padding: 4px 12px;
    border-radius: 5px;
    border: 1px solid #2d6a4f;
    background: #065f46;
    color: #6ee7b7;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    font-family: inherit;
    transition: background 0.1s;
  }

  .run-btn:hover:not(:disabled) {
    background: #047857;
  }

  .run-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }
</style>
