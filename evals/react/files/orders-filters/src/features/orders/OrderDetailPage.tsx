import { Link, useParams } from "react-router";
import { formatPaise, formatPlacedAt } from "./format";
import { useOrder } from "./hooks";
import { StatusBadge } from "./StatusBadge";

export function OrderDetailPage() {
  const { orderId = "" } = useParams();
  const { data, isPending, isError, refetch } = useOrder(orderId);

  if (isPending) return <p role="status">Loading order...</p>;
  if (isError)
    return (
      <div role="alert" className="text-destructive">
        Could not load this order.{" "}
        <button type="button" className="underline" onClick={() => refetch()}>
          Retry
        </button>
      </div>
    );

  return (
    <section aria-labelledby="order-heading">
      <Link to="/orders" className="text-primary underline">
        Back to orders
      </Link>
      <h1 id="order-heading" className="my-4 text-xl font-semibold">
        {data.number} <StatusBadge status={data.status} />
      </h1>
      <p className="text-muted-foreground">
        {data.customerEmail}, placed {formatPlacedAt(data.placedAt)}
      </p>
      <ul className="mt-4">
        {data.lines.map((l) => (
          <li key={l.sku}>
            {l.qty} x {l.name} ({formatPaise(l.pricePaise)})
          </li>
        ))}
      </ul>
      <p className="mt-2 font-semibold">Total {formatPaise(data.totalPaise)}</p>
    </section>
  );
}
