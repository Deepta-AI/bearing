import React from 'react';

export default function InvoiceForm({ invoice }) {
  return (
    <form className="invoice-form">
      <label>Client <input defaultValue={invoice.client} /></label>
      <label>Due date <input type="date" defaultValue={invoice.due} /></label>
      <label>
        Currency
        <select defaultValue="INR">
          <option>INR</option><option>USD</option><option>EUR</option>
        </select>
      </label>
      <label><input type="checkbox" defaultChecked /> Send reminder when overdue</label>
    </form>
  );
}
