import { useEffect, useState } from "react";
import { FileText } from "lucide-react";
import { listInvoices, type Invoice } from "@/api/invoices";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { formatDate, formatINR } from "@/lib/format";

const STATUS: Record<Invoice["status"], { label: string; variant: "secondary" | "success" | "destructive" }> = {
  received: { label: "Received", variant: "secondary" },
  matched: { label: "Matched", variant: "success" },
  disputed: { label: "Disputed", variant: "destructive" },
};

export function InvoicesPage() {
  const [items, setItems] = useState<Invoice[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = () => {
    setError(null);
    setItems(null);
    listInvoices()
      .then((p) => setItems(p.items))
      .catch(() => setError("We could not load invoices. Check your connection and try again."));
  };
  useEffect(load, []);

  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold">Invoices</h1>
      {error && (
        <Alert variant="destructive">
          <AlertTitle>Invoices did not load</AlertTitle>
          <AlertDescription>
            {error}{" "}
            <Button variant="link" className="h-auto p-0" onClick={load}>
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}
      {!error && items === null && (
        <div className="flex flex-col gap-2">
          {Array.from({ length: 6 }, (_, i) => (
            <Skeleton key={i} className="h-11 w-full" />
          ))}
        </div>
      )}
      {items?.length === 0 && (
        <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed p-10 text-center">
          <FileText className="size-6 text-muted-foreground" aria-hidden />
          <p className="font-medium">No invoices yet</p>
          <p className="text-sm text-muted-foreground">Invoices appear here when vendors send them to invoices@payline.example.com.</p>
        </div>
      )}
      {items && items.length > 0 && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Vendor</TableHead>
              <TableHead>Reference</TableHead>
              <TableHead className="text-right">Amount</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Received</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {items.map((inv) => (
              <TableRow key={inv.id}>
                <TableCell className="font-medium">{inv.vendor_name}</TableCell>
                <TableCell className="text-muted-foreground">{inv.invoice_ref}</TableCell>
                <TableCell className="text-right tabular-nums">{formatINR(inv.amount_paise)}</TableCell>
                <TableCell>
                  <Badge variant={STATUS[inv.status].variant}>{STATUS[inv.status].label}</Badge>
                </TableCell>
                <TableCell>{formatDate(inv.received_at)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </section>
  );
}
