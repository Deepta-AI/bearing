import { useEffect, useState } from "react";
import { Link } from "react-router";
import { PAGE_SIZE } from "./api";
import { formatPaise, formatPlacedAt } from "./format";
import { useOrders } from "./hooks";
import type { Order } from "./schemas";
import { StatusBadge } from "./StatusBadge";

export function OrdersPage() {
  const [page, setPage] = useState(1);
  const { data, isPending, isError, refetch } = useOrders(page);
  const [rows, setRows] = useState<Order[]>([]);

  useEffect(() => {
    if (data) setRows(data.items);
  }, [data]);

  const pageCount = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1;

  return (
    <section aria-labelledby="orders-heading">
      <h1 id="orders-heading" className="mb-4 text-xl font-semibold">
        Orders
      </h1>

      {isError && (
        <div role="alert" className="mb-4 text-destructive">
          Could not load orders.{" "}
          <button type="button" className="underline" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      )}

      {isPending && rows.length === 0 ? (
        <p role="status">Loading orders...</p>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-left text-muted-foreground">
            <tr>
              <th className="py-2">Order</th>
              <th>Customer</th>
              <th>Status</th>
              <th className="text-right">Total</th>
              <th>Placed</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((o) => (
              <tr key={o.id} className="border-t border-border">
                <td className="py-2">
                  <Link to={`/orders/${o.id}`} className="text-primary underline">
                    {o.number}
                  </Link>
                </td>
                <td>{o.customerEmail}</td>
                <td>
                  <StatusBadge status={o.status} />
                </td>
                <td className="text-right">{formatPaise(o.totalPaise)}</td>
                <td>{formatPlacedAt(o.placedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <nav aria-label="Pagination" className="mt-4 flex items-center gap-3">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Previous
        </button>
        <span>
          Page {page} of {pageCount}
        </span>
        <button type="button" disabled={page >= pageCount} onClick={() => setPage((p) => p + 1)}>
          Next
        </button>
      </nav>
    </section>
  );
}
