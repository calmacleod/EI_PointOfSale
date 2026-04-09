import { useState, useEffect, useRef } from "react"
import { router } from "@inertiajs/react"
import TabBar from "./components/TabBar"
import OrderStatusBar from "./components/OrderStatusBar"
import LineItemsTable from "./components/LineItemsTable"
import CodeLookupBar from "./components/CodeLookupBar"
import CustomerPanel from "./components/CustomerPanel"
import DiscountsPanel from "./components/DiscountsPanel"
import TotalsPanel from "./components/TotalsPanel"
import PaymentsPanel from "./components/PaymentsPanel"
import ActionButtons from "./components/ActionButtons"
import PaymentModal from "./components/PaymentModal"
import ProductSearchModal from "./components/ProductSearchModal"
import CustomerSearchModal from "./components/CustomerSearchModal"
import CancelConfirmModal from "./components/CancelConfirmModal"

export default function Show({ order, active_orders, held_count, routes }) {
  const [showPaymentModal, setShowPaymentModal] = useState(false)
  const [showProductSearch, setShowProductSearch] = useState(false)
  const [showCustomerSearch, setShowCustomerSearch] = useState(false)
  const [cancelConfirm, setCancelConfirm] = useState(null)
  const [showRightPanel, setShowRightPanel] = useState(false)
  const codeInputRef = useRef(null)

  // Refocus the code input after Inertia page updates
  useEffect(() => {
    if (!showPaymentModal && !showProductSearch && !showCustomerSearch && !cancelConfirm) {
      codeInputRef.current?.focus()
    }
  }, [order, showPaymentModal, showProductSearch, showCustomerSearch, cancelConfirm])

  function reload() {
    router.reload({ only: ["order"] })
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
      <TabBar
        activeOrders={active_orders}
        currentOrderId={order.id}
        heldCount={held_count}
        newOrderUrl={routes.new_order}
        registerUrl="/inertia/register"
      />

      <OrderStatusBar
        order={order}
        onCancel={() => setCancelConfirm({ orderNumber: order.number, cancelUrl: routes.cancel })}
      />

      <div className="flex min-h-0 flex-1 overflow-hidden">
        {/* Left column */}
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
          <div className="min-h-0 flex-1 overflow-y-auto">
            <LineItemsTable
              order={order}
              onReload={reload}
            />
          </div>
          <CodeLookupBar
            order={order}
            routes={routes}
            onReload={reload}
            onOpenProductSearch={() => setShowProductSearch(true)}
          />
        </div>

        {/* Right panel toggle (mobile) */}
        <button
          type="button"
          onClick={() => setShowRightPanel(!showRightPanel)}
          className="absolute right-3 top-[calc(2.25rem+2.5rem+2rem)] z-10 flex h-7 w-7 items-center justify-center rounded-full border border-theme bg-surface text-xs shadow lg:hidden"
          aria-label="Toggle order details"
        >
          <svg className={`h-3 w-3 transition-transform ${showRightPanel ? "rotate-180" : ""}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>

        {/* Right column */}
        <div className={`${showRightPanel ? "flex" : "hidden"} lg:flex w-72 xl:w-80 flex-col overflow-y-auto border-l border-theme bg-surface shrink-0`}>
          <CustomerPanel
            order={order}
            onAssign={() => setShowCustomerSearch(true)}
            onRemove={() => {
              fetch(routes.remove_customer, {
                method: "DELETE",
                headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
              }).then(() => reload())
            }}
          />
          <DiscountsPanel
            order={order}
            onRemoveDiscount={(url) => {
              fetch(url, {
                method: "DELETE",
                headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
              }).then(() => reload())
            }}
          />
          <TotalsPanel order={order} />
          <PaymentsPanel
            order={order}
            onAddPayment={() => setShowPaymentModal(true)}
            onRemovePayment={(url) => {
              fetch(url, {
                method: "DELETE",
                headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" },
              }).then(() => reload())
            }}
          />
          <ActionButtons order={order} routes={routes} onReload={reload} />
        </div>
      </div>

      {showPaymentModal && (
        <PaymentModal
          order={order}
          routes={routes}
          onClose={() => setShowPaymentModal(false)}
          onSuccess={() => { setShowPaymentModal(false); reload() }}
        />
      )}

      {showProductSearch && (
        <ProductSearchModal
          order={order}
          routes={routes}
          onClose={() => setShowProductSearch(false)}
          onAdded={() => { setShowProductSearch(false); reload() }}
        />
      )}

      {showCustomerSearch && (
        <CustomerSearchModal
          order={order}
          routes={routes}
          onClose={() => setShowCustomerSearch(false)}
          onAssigned={() => { setShowCustomerSearch(false); reload() }}
        />
      )}

      {cancelConfirm && (
        <CancelConfirmModal
          orderNumber={cancelConfirm.orderNumber}
          cancelUrl={cancelConfirm.cancelUrl}
          onClose={() => setCancelConfirm(null)}
        />
      )}
    </div>
  )
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
}
