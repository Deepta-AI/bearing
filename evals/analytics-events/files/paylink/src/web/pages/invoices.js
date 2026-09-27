// The merchant's invoice list: sending an invoice.
export async function sendInvoice(api, analytics, invoice, channel) {
  await api.post(`/api/invoices/${invoice.id}/send`, { channel });
  analytics.track('invoice_sent', { invoice_id: invoice.id, channel });
}
