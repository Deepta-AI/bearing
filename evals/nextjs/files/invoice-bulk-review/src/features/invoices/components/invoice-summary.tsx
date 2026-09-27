import { getInvoiceSummary } from "@/features/invoices/api";
import { formatPaise } from "@/features/invoices/format";

export async function InvoiceSummary() {
  const s = await getInvoiceSummary();
  return (
    <dl>
      <dt>Outstanding</dt>
      <dd>{formatPaise(s.outstanding)}</dd>
      <dt>Overdue</dt>
      <dd>{formatPaise(s.overdue)}</dd>
      <dt>Paid this month</dt>
      <dd>{formatPaise(s.paidThisMonth)}</dd>
    </dl>
  );
}
