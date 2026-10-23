<script>
  import AuthPage from "./components/AuthPage.svelte"
  import DashboardPage from "./components/DashboardPage.svelte"
  import ResourceIndex from "./components/ResourceIndex.svelte"
  import ResourceForm from "./components/ResourceForm.svelte"
  import ResourceShow from "./components/ResourceShow.svelte"
  import RegisterPage from "./components/RegisterPage.svelte"
  import SpecialPage from "./components/SpecialPage.svelte"
  import OfflinePage from "./components/OfflinePage.svelte"
  import HelpPage from "./components/HelpPage.svelte"
  import ReportsPage from "./components/ReportsPage.svelte"

  export let view = "operations"
  export let title = ""
  export let description = ""
  export let form = null
  export let secondary = null
  export let columns = []
  export let rows = []
  export let filters = []
  export let query = {}
  export let pagination = null
  export let pagination_path = null
  export let actions = {}
  export let can_create = false
  export let empty_message = "No records found."
  export let templates = []
  export let details = []
  export let cards = []
  export let metrics = []
  export let metrics_last_updated = null
  export let drawer = null
  export let recent_orders = []
  export let tasks = []
  export let order = null
  export let active_orders = []
  export let held_count = 0
  export let events = []
  export let store = null
  export let receipt_lines = []
  export let action = null
  export let errors = []
  export let session = null
  export let pending_reconciliation = null
  export let recent_sessions = []
  export let denominations = []
  export let reconciliation = null
  export let report = null
  export let notifications = []
  export let unread_count = 0
  export let certificate = null
  export let redemptions = []
  export let preview_lines = []
  export let files = []
  export let status = null
  export let recurring_tasks = []
  export let recent_imports = []
  export let flash = {}
  export let sync_paths = null
  export let home_path = "/"
  export let allow_fake_offline = false
  export let guides = []
  export let article = null
</script>

<svelte:head><title>{title ? `${title} - EI Point of Sale` : "EI Point of Sale"}</title></svelte:head>

{#if view === "auth"}
  <AuthPage {title} {description} {form} {secondary} />
{:else if view === "dashboard"}
  <DashboardPage {title} {description} {metrics} {metrics_last_updated} {drawer} {recent_orders} {tasks} {actions} />
{:else if view === "resource_index"}
  <ResourceIndex {title} {description} {columns} {rows} {filters} {query} {pagination} {actions} {can_create} {empty_message} />
{:else if view === "resource_form"}
  <ResourceForm {title} {description} {form} />
{:else if view === "resource_show"}
  <ResourceShow {title} {description} {details} {actions} />
{:else if view === "register"}
  <RegisterPage {order} {active_orders} {held_count} {actions} {flash} />
{:else if view === "offline"}
  <OfflinePage {sync_paths} {home_path} {allow_fake_offline} />
{:else if view === "help"}
  <HelpPage {guides} {article} {actions} />
{:else if ["report_library", "report_form", "report_show"].includes(view)}
  {#key `${view}-${report?.id || form?.report_type || "library"}`}
    <ReportsPage {view} {title} {description} {templates} {columns} {rows} {filters} {query} {pagination} {can_create} {actions} {form} {report} />
  {/key}
{:else}
  {#key `${view}-${order?.id || session?.id || certificate?.code || action || ""}`}
    <SpecialPage {view} {title} {details} {actions} {cards} {order} {events} {store} {receipt_lines} {action} {errors} {session} {pending_reconciliation} {recent_sessions} {denominations} {reconciliation} {notifications} {unread_count} {certificate} {redemptions} {preview_lines} {files} {status} {recurring_tasks} {recent_imports} {query} {pagination} {pagination_path} />
  {/key}
{/if}
