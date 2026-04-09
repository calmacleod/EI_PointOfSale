const formatter = new Intl.NumberFormat("en-CA", {
  style: "currency",
  currency: "CAD",
  currencyDisplay: "symbol",
})

export function formatCurrency(amount) {
  return formatter.format(amount ?? 0)
}
