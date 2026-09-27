export function sortByCustomer(invoices) {
  return [...invoices].sort((a, b) => (a.customer < b.customer ? -1 : 1));
}
