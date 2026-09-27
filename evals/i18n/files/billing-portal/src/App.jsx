import { useEffect, useState } from 'react';
import { getMe, listInvoices } from './api.js';
import Header from './components/Header.jsx';
import InvoiceList from './components/InvoiceList.jsx';
import InvoiceDetail from './components/InvoiceDetail.jsx';

export default function App() {
  const [me, setMe] = useState(null);
  const [invoices, setInvoices] = useState([]);
  const [selected, setSelected] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    getMe().then(setMe).catch(setError);
    listInvoices().then(setInvoices).catch(setError);
  }, []);

  if (error) return <p role="alert">{error.message}</p>;
  if (!me) return <p>Loading...</p>;

  return (
    <div className="app">
      <Header name={me.name} />
      {selected ? (
        <InvoiceDetail invoice={selected} onBack={() => setSelected(null)} />
      ) : (
        <InvoiceList invoices={invoices} onOpen={setSelected} />
      )}
    </div>
  );
}
