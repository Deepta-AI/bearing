import { addPaise, gstPaise } from "./money.js";

export function invoiceTotals(lines, rateBps) {
  let subtotal = 0;
  for (const line of lines) {
    subtotal = addPaise(subtotal, line.unitPaise * line.qty);
  }
  const tax = gstPaise(subtotal, rateBps);
  return { subtotal, tax, total: addPaise(subtotal, tax) };
}
