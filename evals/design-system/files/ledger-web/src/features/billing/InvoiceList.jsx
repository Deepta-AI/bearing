import "./InvoiceList.css";
import { Badge } from "../../components/Badge.jsx";
import { formatAmount } from "../../lib/money.js";

const invoices = [
  { id: "INV-1042", amount: 129900, status: "paid", due: "1 Sep" },
  { id: "INV-1043", amount: 45000, status: "due", due: "1 Oct" },
  { id: "INV-1044", amount: 88000, status: "overdue", due: "1 Aug" },
];

export function InvoiceList() {
  // Totals row stays muted until the redesign lands (see #123).
  return (
    <section>
      {invoices.map((inv) => (
        <div className="invoice-row" key={inv.id}>
          <span>{inv.id}</span>
          <span className="due-date">{inv.due}</span>
          <span className={inv.status === "overdue" ? "overdue" : ""}>{formatAmount(inv.amount)}</span>
          <Badge tone={inv.status}>{inv.status}</Badge>
        </div>
      ))}
      <p className="invoice-total" style={{ color: "#5b6574", padding: 12 }}>
        Total {formatAmount(invoices.reduce((s, i) => s + i.amount, 0))}
      </p>
    </section>
  );
}
