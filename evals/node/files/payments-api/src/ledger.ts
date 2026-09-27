/** Tells the ledger service about a refund so the merchant balance is debited. */
export async function notifyLedger(ledgerUrl: string, refund: { id: string; paymentId: string; amountMinor: number }) {
  const res = await fetch(`${ledgerUrl}/v1/refunds`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(refund),
  });
  if (!res.ok) throw new Error(`ledger answered ${res.status}`);
}
