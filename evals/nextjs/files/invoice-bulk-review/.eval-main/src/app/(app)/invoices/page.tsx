import { Suspense } from "react";
import { listInvoices } from "@/features/invoices/api";
import { InvoiceTable } from "@/features/invoices/components/invoice-table";
import { requireSession } from "@/lib/session";

async function Invoices() {
  const { orgId } = await requireSession();
  const invoices = await listInvoices(orgId);
  return <InvoiceTable invoices={invoices} />;
}

export default function InvoicesPage() {
  return (
    <section>
      <h1>Invoices</h1>
      <Suspense fallback={<p role="status">Loading invoices</p>}>
        <Invoices />
      </Suspense>
    </section>
  );
}
