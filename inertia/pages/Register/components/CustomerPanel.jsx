export default function CustomerPanel({ order, onAssign, onRemove }) {
  const { customer } = order
  const isDraft = order.status === "draft"

  return (
    <div className="border-b border-theme p-3">
      <div className="mb-1.5 flex items-center justify-between">
        <span className="text-xs font-semibold text-muted uppercase tracking-wide">Customer</span>
        {customer && isDraft && (
          <button type="button" onClick={onRemove} className="text-xs text-muted hover:text-red-600">
            Remove
          </button>
        )}
      </div>

      {customer ? (
        <div>
          <div className="font-medium text-sm text-body">{customer.name}</div>
          {customer.member_number && (
            <div className="text-xs text-muted">Member #{customer.member_number}</div>
          )}
          {customer.tax_code && (
            <span className="mt-1 inline-block rounded bg-blue-100 px-1.5 py-0.5 text-[10px] font-medium text-blue-700">
              {customer.tax_code.name}
            </span>
          )}
        </div>
      ) : (
        <div className="text-sm text-muted">Quick Sale</div>
      )}

      {isDraft && (
        <button
          type="button"
          onClick={onAssign}
          className="mt-2 w-full rounded border border-theme px-2 py-1 text-xs text-muted hover:bg-(--color-border)"
        >
          {customer ? "Change Customer" : "Search & Assign Customer"}
        </button>
      )}
    </div>
  )
}
