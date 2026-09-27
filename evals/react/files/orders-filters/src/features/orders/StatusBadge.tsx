import type { OrderStatus } from "./schemas";

const LABELS: Record<OrderStatus, string> = {
  pending: "Pending",
  paid: "Paid",
  shipped: "Shipped",
  cancelled: "Cancelled",
};

const TONES: Record<OrderStatus, string> = {
  pending: "bg-amber-100 text-amber-900",
  paid: "bg-sky-100 text-sky-900",
  shipped: "bg-emerald-100 text-emerald-900",
  cancelled: "bg-zinc-200 text-zinc-800",
};

export function StatusBadge({ status }: { status: OrderStatus }) {
  return <span className={`rounded-md px-2 py-0.5 text-xs ${TONES[status]}`}>{LABELS[status]}</span>;
}
