import { Suspense } from "react";
import { bulkDelete } from "@/features/invoices/actions";
import { listInvoices } from "@/features/invoices/api";
import { BulkToolbar } from "@/features/invoices/components/bulk-toolbar";
import { InvoiceSummary } from "@/features/invoices/components/invoice-summary";
import { InvoiceTable } from "@/features/invoices/components/invoice-table";
import { requireSession } from "@/lib/session";

async function Invoices() {
  const { orgId } = await requireSession();
  const invoices = await listInvoices(orgId);
  return (
    <>
      <BulkToolbar
        orgId={orgId}
        ids={invoices.map((i) => i.id)}
        removeAction={bulkDelete.bind(null, orgId)}
      />
      <InvoiceTable invoices={invoices} />
    </>
  );
}

export default function InvoicesPage() {
  return (
    <section>
      <h1>Invoices</h1>
      <Suspense fallback={<p role="status">Loading summary</p>}>
        <InvoiceSummary />
      </Suspense>
      <Suspense fallback={<p role="status">Loading invoices</p>}>
        <Invoices />
      </Suspense>
    </section>
  );
}
