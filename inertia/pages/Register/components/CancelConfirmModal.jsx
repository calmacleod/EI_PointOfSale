import { router } from "@inertiajs/react"

export default function CancelConfirmModal({ orderNumber, cancelUrl, onClose }) {
  function confirm() {
    router.delete(cancelUrl)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="w-full max-w-sm rounded-xl border border-theme bg-surface p-6 shadow-xl">
        <h2 className="mb-2 text-base font-semibold text-body">Cancel Order {orderNumber}?</h2>
        <p className="mb-4 text-sm text-muted">This will permanently cancel the order and cannot be undone.</p>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded border border-theme px-3 py-1.5 text-sm text-body hover:bg-(--color-border)"
          >
            Keep Order
          </button>
          <button
            type="button"
            onClick={confirm}
            className="flex-1 rounded bg-red-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-700"
          >
            Cancel Order
          </button>
        </div>
      </div>
    </div>
  )
}
