export function formatMoney(amountMinor, currency) {
  const symbol = currency === 'INR' ? '₹' : '$';
  return `${symbol}${(amountMinor / 100).toFixed(2)}`;
}

// The invoice as the payer sees it. Used by the payer page and by the
// merchant's preview, so both show exactly the same thing.
export function renderInvoice(invoice) {
  const rows = invoice.lines
    .map((l) => `<tr><td>${l.description}</td><td>${l.qty}</td><td>${formatMoney(l.qty * l.unitMinor, invoice.currency)}</td></tr>`)
    .join('');
  return `<article class="invoice">
  <h1>Invoice ${invoice.number}</h1>
  <p>For ${invoice.customerName}</p>
  <table>${rows}</table>
  <p class="total">Total ${formatMoney(invoice.amountMinor, invoice.currency)}</p>
</article>`;
}
