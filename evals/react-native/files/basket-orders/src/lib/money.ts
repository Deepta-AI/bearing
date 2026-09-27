const formatters = new Map<string, Intl.NumberFormat>();

/** Display text for an amount in minor units, e.g. formatMoney(124950, 'INR') is "₹1,249.50". */
export function formatMoney(minor: number, currency: string): string {
  let f = formatters.get(currency);
  if (!f) {
    f = new Intl.NumberFormat('en-IN', { style: 'currency', currency });
    formatters.set(currency, f);
  }
  return f.format(minor / 100);
}
