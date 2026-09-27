import { renderInvoice } from '../components/invoice-view.js';

// The payer page at /pay/<token>. `query` is the parsed query string.
export function renderPayPage(invoice, query = {}) {
  if (query.status === 'success' || invoice.status === 'paid') {
    return `<main><h1>Thank you!</h1><p>Your payment is complete.</p></main>`;
  }
  return `<main>
${renderInvoice(invoice)}
<form id="pay">
  <fieldset><legend>Pay with</legend>
    <label><input type="radio" name="method" value="card" checked> Card</label>
    <label><input type="radio" name="method" value="upi"> UPI</label>
    <label><input type="radio" name="method" value="netbanking"> Netbanking</label>
  </fieldset>
  <label>Email for your receipt <input type="email" name="receiptEmail"></label>
  <label>Note to the merchant (optional) <textarea name="note" maxlength="500"></textarea></label>
  <button type="submit">Pay now</button>
</form>
</main>`;
}

// Submit handler: asks the server for a provider session and returns the
// URL to send the payer to.
export async function submitPayment(api, token, form) {
  const res = await api.post(`/api/pay/${token}/checkout`, {
    method: form.method,
    receiptEmail: form.receiptEmail || null,
    note: form.note || null,
  });
  return res.redirectUrl;
}
