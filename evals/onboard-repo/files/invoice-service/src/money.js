// Amounts are integer paise everywhere. Never a float, never rupees.

export function addPaise(a, b) {
  if (!Number.isInteger(a) || !Number.isInteger(b)) {
    throw new TypeError("amounts must be integer paise");
  }
  return a + b;
}

// GST at a rate in basis points (1800 = 18%), rounded half up to the paisa.
export function gstPaise(amount, rateBps) {
  return Math.floor((amount * rateBps + 5000) / 10000);
}

export function formatRupees(paise) {
  const sign = paise < 0 ? "-" : "";
  const abs = Math.abs(paise);
  return `${sign}Rs ${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, "0")}`;
}
