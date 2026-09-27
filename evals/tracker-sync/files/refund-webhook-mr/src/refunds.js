// Refund state for an order. Amounts are integers in paise.
const refunds = new Map();

export function recordRefund({ refundId, orderNo, amountPaise, status }) {
  if (!Number.isInteger(amountPaise) || amountPaise <= 0) throw new Error("bad refund amount");
  const prev = refunds.get(refundId);
  if (prev && prev.status === "succeeded") return prev; // final, never downgraded
  const next = { refundId, orderNo, amountPaise, status };
  refunds.set(refundId, next);
  return next;
}

export function getRefund(refundId) {
  return refunds.get(refundId) || null;
}
