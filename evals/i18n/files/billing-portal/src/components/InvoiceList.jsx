import { useState } from 'react';
import { formatDate, formatMoney, overdueLabel } from '../lib/format.js';
import { sortByCustomer } from '../lib/invoices.js';

export default function InvoiceList({ invoices, onOpen }) {
  const [query, setQuery] = useState('');
  const overdue = invoices.filter((i) => i.status === 'overdue').length;
  const shown = sortByCustomer(
    invoices.filter((i) => i.customer.toLowerCase().includes(query.toLowerCase())),
  );

  return (
    <section>
      <h2>Invoices</h2>
      {overdue > 0 && <div className="banner">{overdueLabel(overdue)}</div>}
      <input
        type="search"
        placeholder="Search invoices"
        aria-label="Search invoices"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {shown.length === 0 ? (
        <p className="empty">No invoices yet</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Customer</th>
              <th>Issued</th>
              <th>Amount</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {shown.map((inv) => (
              <tr key={inv.id} onClick={() => onOpen(inv)}>
                <td>{inv.customer}</td>
                <td>{formatDate(inv.issuedAt)}</td>
                <td className="amount">{formatMoney(inv.amountPaise)}</td>
                <td>
                  <a href={`/api/invoices/${inv.id}/pdf`} aria-label="Download PDF">
                    PDF
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
