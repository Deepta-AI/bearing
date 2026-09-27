import { formatPaise } from "@/features/invoices/format";
import type { Invoice } from "@/features/invoices/schemas";
import { VoidButton } from "./void-button";

export function InvoiceTable({ invoices }: { invoices: Invoice[] }) {
  return (
    <table>
      <thead>
        <tr>
          <th scope="col">Number</th>
          <th scope="col">Customer</th>
          <th scope="col">Amount</th>
          <th scope="col">Status</th>
          <th scope="col">Due</th>
          <th scope="col">
            <span className="sr-only">Actions</span>
          </th>
        </tr>
      </thead>
      <tbody>
        {invoices.map((inv) => (
          <tr key={inv.id}>
            <td>{inv.number}</td>
            <td>{inv.customer}</td>
            <td>{formatPaise(inv.amount)}</td>
            <td>{inv.status}</td>
            <td>{inv.dueOn}</td>
            <td>{inv.status === "issued" && <VoidButton id={inv.id} number={inv.number} />}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
