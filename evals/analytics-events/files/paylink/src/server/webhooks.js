// Applies a verified provider webhook to the invoice. Must return 200 for
// events it has already seen, or the provider keeps retrying.
export function handlePaymentWebhook(store, evt) {
  const invoice = store.byId(evt.data.invoice_id);
  if (!invoice) return { status: 404 };
  if (evt.type === 'payment.succeeded') {
    invoice.status = 'paid';
    invoice.paidAt = evt.created_at;
    invoice.paymentMethod = evt.data.method;
  } else if (evt.type === 'payment.failed') {
    invoice.lastFailure = { code: evt.data.failure_code, message: evt.data.failure_message };
  }
  return { status: 200 };
}
