// Invoice arithmetic in integer paise, so no float ever reaches a total.

export function lineTotal(unitPaise, quantity) {
  if (!Number.isInteger(unitPaise) || !Number.isInteger(quantity) || quantity < 0) {
    throw new RangeError("unitPaise and quantity must be non-negative integers");
  }
  return unitPaise * quantity;
}

// GST at a percentage, rounded half up to the paisa.
export function taxPaise(amountPaise, ratePercent) {
  return Math.floor((amountPaise * ratePercent + 50) / 100);
}

export function invoiceTotal(lines, ratePercent) {
  const subtotal = lines.reduce((sum, l) => sum + lineTotal(l.unitPaise, l.quantity), 0);
  const tax = taxPaise(subtotal, ratePercent);
  return { subtotal, tax, total: subtotal + tax };
}
