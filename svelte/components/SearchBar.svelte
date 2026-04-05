<script>
  let { onSearch, placeholder = "Search by name or code…" } = $props()

  let query = $state("")
  let timer

  function handleInput(e) {
    query = e.target.value
    clearTimeout(timer)
    timer = setTimeout(() => onSearch(query), 200)
  }

  function handleKeydown(e) {
    if (e.key === "Escape") {
      query = ""
      onSearch("")
    }
  }
</script>

<div class="search-wrap">
  <div class="search-icon-wrap">
    <svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
  </div>
  <input
    type="search"
    {placeholder}
    value={query}
    oninput={handleInput}
    onkeydown={handleKeydown}
    class="search-input"
    autofocus
  />
  {#if query}
    <button
      onclick={() => { query = ""; onSearch("") }}
      class="clear-btn"
    >
      <svg class="clear-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  {/if}
</div>

<style>
  .search-wrap {
    position: relative;
  }

  .search-icon-wrap {
    position: absolute;
    top: 0;
    bottom: 0;
    left: 12px;
    display: flex;
    align-items: center;
    pointer-events: none;
  }

  .search-icon {
    width: 16px;
    height: 16px;
    color: #6b6b6b;
  }

  .search-input {
    width: 100%;
    box-sizing: border-box;
    border-radius: 8px;
    border: 1px solid #c8c8c8;
    background: white;
    padding: 10px 16px 10px 36px;
    font-size: 14px;
    color: #1a1a1a;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.07);
    outline: none;
    transition: border-color 0.15s, box-shadow 0.15s;
  }

  .search-input::placeholder {
    color: #6b6b6b;
  }

  .search-input:focus {
    border-color: #0d9488;
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.07), 0 0 0 1px #0d9488;
  }

  .clear-btn {
    position: absolute;
    top: 0;
    bottom: 0;
    right: 12px;
    display: flex;
    align-items: center;
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    color: #6b6b6b;
    transition: color 0.1s;
  }

  .clear-btn:hover {
    color: #1a1a1a;
  }

  .clear-icon {
    width: 14px;
    height: 14px;
  }
</style>
