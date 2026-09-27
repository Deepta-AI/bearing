// Spike for SHOP-66 (backlog CHK-6, pay with a saved card): the request that
// charges a saved card through the provider's token API (ADR-0003). Not wired
// into checkout yet.
export function tokenChargeRequest(card, totalPaise, orderNo) {
  if (!card || !card.token) throw new Error("a saved card token is required");
  if (!Number.isInteger(totalPaise) || totalPaise <= 0) throw new Error("bad amount");
  return { token: card.token, amount: totalPaise, currency: "INR", reference: orderNo };
}
