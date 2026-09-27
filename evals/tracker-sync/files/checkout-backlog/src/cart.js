// Cart totals in paise (integers), so rounding never drifts.
export function lineTotal(item) {
  if (!Number.isInteger(item.pricePaise) || item.pricePaise < 0) {
    throw new Error(`bad price for ${item.sku}`);
  }
  if (!Number.isInteger(item.qty) || item.qty < 1) {
    throw new Error(`bad quantity for ${item.sku}`);
  }
  return item.pricePaise * item.qty;
}

export function cartTotal(items) {
  return items.reduce((sum, item) => sum + lineTotal(item), 0);
}
