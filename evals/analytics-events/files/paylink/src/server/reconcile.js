// Catches payments whose webhook never arrived (the provider stops retrying
// after three days). The scheduler runs it every six hours; it asks the
// provider about every invoice that has an open payment session.
export async function reconcilePayments(store, provider) {
  let applied = 0;
  for (const inv of store.withOpenSession()) {
    const payment = await provider.getPayment(inv.sessionId);
    if (payment.status === 'succeeded' && inv.status !== 'paid') {
      inv.status = 'paid';
      inv.paidAt = payment.paid_at;
      inv.paymentMethod = payment.method;
      applied++;
    }
  }
  return applied;
}
