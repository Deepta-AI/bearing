import React from 'react';
import './InvoiceTable.css';
import { formatMoney } from '../lib/format.js';

export default function InvoiceTable({ invoices, onOpen }) {
  return (
    <table className="invoice-table card">
      <thead>
        <tr><th>Invoice</th><th>Client</th><th>Due</th><th>Total</th><th>Status</th></tr>
      </thead>
      <tbody>
        {invoices.map((inv) => (
          <tr key={inv.id} onClick={() => onOpen(inv)}>
            <td>{inv.id}</td>
            <td>{inv.client}</td>
            <td className="muted">{inv.due}</td>
            <td>{formatMoney(inv.total)}</td>
            <td><span className={`badge badge--${inv.status}`}>{inv.status}</span></td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
