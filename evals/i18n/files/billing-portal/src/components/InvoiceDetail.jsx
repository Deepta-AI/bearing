import { useState } from 'react';
import { payInvoice } from '../api.js';
import { daysUntil, formatDate, formatMoney } from '../lib/format.js';

export default function InvoiceDetail({ invoice, onBack }) {
  const [status, setStatus] = useState(invoice.status);
  const [error, setError] = useState(null);
  const days = daysUntil(invoice.dueAt, new Date());

  async function pay() {
    setError(null);
    try {
      await payInvoice(invoice.id);
      setStatus('paid');
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <section>
      <button onClick={onBack} title="Back to invoices">
        &larr; Back
      </button>
      <h2>{'Invoice ' + invoice.number}</h2>
      <p className="amount">{formatMoney(invoice.amountPaise)}</p>
      {status === 'paid' ? (
        <p>Paid on {formatDate(invoice.paidAt)}</p>
      ) : (
        <>
          <p>{'Due in ' + days + ' days'}</p>
          <button onClick={pay}>Pay now</button>
        </>
      )}
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
