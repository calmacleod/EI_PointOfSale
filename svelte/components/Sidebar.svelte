<script>
  let { activePage = "products", onNavigate } = $props()

  const navItems = [
    {
      id: "products",
      label: "Product Lookup",
      icon: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z",
    },
    {
      id: "services",
      label: "Services",
      icon: "M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
    },
    {
      id: "tax_codes",
      label: "Tax Codes",
      icon: "M9 14l6-6m-5.5.5h.01m4.99 5h.01M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16l3.5-2 3.5 2 3.5-2 3.5 2z",
    },
    {
      id: "customers",
      label: "Customers",
      icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z",
    },
    {
      id: "cart",
      label: "Order Calculator",
      icon: "M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z",
    },
  ]
</script>


<aside class="sidebar">
  <!-- Brand -->
  <div class="brand">
    <div class="brand-logo">EI</div>
    <div class="brand-text">
      <p class="brand-name">Point of Sale</p>
      <p class="brand-sub">Offline Mode</p>
    </div>
  </div>

  <!-- Offline notice -->
  <div class="offline-notice-wrap">
    <div class="offline-notice">
      <div class="offline-notice-inner">
        <svg class="offline-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636a9 9 0 010 12.728M15.536 8.464a5 5 0 010 7.072M6 18L18 6M8.464 15.536a5 5 0 010-7.072M5.636 18.364a9 9 0 010-12.728"/>
        </svg>
        <div>
          <p class="offline-title">App is offline</p>
          <p class="offline-body">Limited features available. Data lookup works with locally cached data.</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Navigation -->
  <nav class="nav">
    <p class="nav-section-label">Available offline</p>

    {#each navItems as item}
      <button
        onclick={() => onNavigate(item.id)}
        class="nav-item"
        class:active={activePage === item.id}
      >
        <svg class="nav-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d={item.icon}/>
        </svg>
        <span class="nav-label">{item.label}</span>
      </button>
    {/each}

    <p class="nav-section-label nav-section-label--spaced">Requires connection</p>

    {#each [
      { label: "Register", icon: "M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" },
      { label: "Orders", icon: "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" },
      { label: "Reports", icon: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" },
    ] as item}
      <div class="nav-item nav-item--disabled">
        <svg class="nav-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d={item.icon}/>
        </svg>
        <span class="nav-label">{item.label}</span>
      </div>
    {/each}
  </nav>

  <!-- Bottom: back link -->
  <div class="sidebar-footer">
    <a href="/" class="back-link">
      <svg class="back-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.75" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
      </svg>
      <span class="nav-label">Back to POS</span>
    </a>
  </div>
</aside>

<style>
  .sidebar {
    display: flex;
    flex-direction: column;
    width: 224px;
    flex-shrink: 0;
    overflow: hidden;
    border-right: 1px solid #dcdce0;
    background: #f5f5f7;
  }

  /* Brand */
  .brand {
    display: flex;
    align-items: center;
    gap: 10px;
    border-bottom: 1px solid #dcdce0;
    padding: 10px 12px;
  }

  .brand-logo {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    border-radius: 6px;
    background: #0d9488;
    font-size: 10px;
    font-weight: 700;
    color: white;
    user-select: none;
  }

  .brand-text {
    min-width: 0;
    flex: 1;
  }

  .brand-name {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .brand-sub {
    margin: 0;
    font-size: 11px;
    color: #8e8e9a;
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Offline notice */
  .offline-notice-wrap {
    border-bottom: 1px solid #dcdce0;
    padding: 12px;
  }

  .offline-notice {
    border-radius: 6px;
    border: 1px solid #fde68a;
    background: #fffbeb;
    padding: 10px 12px;
  }

  .offline-notice-inner {
    display: flex;
    align-items: flex-start;
    gap: 8px;
  }

  .offline-icon {
    width: 14px;
    height: 14px;
    flex-shrink: 0;
    color: #d97706;
    margin-top: 2px;
  }

  .offline-title {
    margin: 0;
    font-size: 12px;
    font-weight: 600;
    color: #92400e;
  }

  .offline-body {
    margin: 2px 0 0;
    font-size: 11px;
    line-height: 1.4;
    color: #b45309;
  }

  /* Navigation */
  .nav {
    flex: 1;
    overflow-y: auto;
    padding: 8px 10px;
  }

  .nav-section-label {
    margin: 0 0 4px;
    padding: 0 8px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #8e8e9a;
  }

  .nav-section-label--spaced {
    margin-top: 12px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    height: 30px;
    padding: 0 8px;
    border: none;
    border-radius: 6px;
    background: transparent;
    font-size: 13px;
    font-weight: 500;
    color: #555566;
    text-align: left;
    cursor: pointer;
    text-decoration: none;
    transition: background 0.1s, color 0.1s;
  }

  .nav-item:hover {
    background: rgba(0, 0, 0, 0.04);
    color: #1a1a2e;
  }

  .nav-item.active {
    background: rgba(0, 0, 0, 0.07);
    color: #1a1a2e;
  }

  .nav-item--disabled {
    cursor: not-allowed;
    opacity: 0.35;
  }

  .nav-item--disabled:hover {
    background: transparent;
    color: #555566;
  }

  .nav-icon {
    width: 16px;
    height: 16px;
    flex-shrink: 0;
  }

  .nav-label {
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Footer */
  .sidebar-footer {
    flex-shrink: 0;
    border-top: 1px solid #dcdce0;
    padding: 8px 10px;
  }

  .back-link {
    display: flex;
    align-items: center;
    gap: 10px;
    height: 30px;
    padding: 0 8px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    color: #555566;
    text-decoration: none;
    transition: background 0.1s, color 0.1s;
  }

  .back-link:hover {
    background: rgba(0, 0, 0, 0.04);
    color: #1a1a2e;
  }

  .back-icon {
    width: 16px;
    height: 16px;
    flex-shrink: 0;
    opacity: 0.5;
  }
</style>
