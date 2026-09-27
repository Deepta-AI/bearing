import React, { useState } from 'react';
import InvoiceTable from './components/InvoiceTable.jsx';
import InvoiceForm from './components/InvoiceForm.jsx';
import RevenueChart from './components/RevenueChart.jsx';
import SettingsMenu from './components/SettingsMenu.jsx';
import Modal from './components/Modal.jsx';

const invoices = [
  { id: 'INV-1041', client: 'Harbour Books', total: 124000, status: 'paid', due: '2026-09-01' },
  { id: 'INV-1042', client: 'North Street Cafe', total: 38950, status: 'overdue', due: '2026-09-10' },
  { id: 'INV-1043', client: 'Kiln & Co', total: 76000, status: 'draft', due: '2026-10-05' },
];

export default function App() {
  const [editing, setEditing] = useState(null);
  return (
    <div className="app">
      <header className="app-header">
        <h1>Invoices</h1>
        <SettingsMenu />
      </header>
      <main>
        <RevenueChart months={[42000, 51000, 47500, 63000, 58000, 71000]} />
        <InvoiceTable invoices={invoices} onOpen={setEditing} />
      </main>
      {editing && (
        <Modal title={editing.id} onClose={() => setEditing(null)}>
          <InvoiceForm invoice={editing} />
          <button className="button" onClick={() => window.print()}>Print or save as PDF</button>
        </Modal>
      )}
    </div>
  );
}
