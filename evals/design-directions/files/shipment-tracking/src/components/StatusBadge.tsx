import { Badge } from "@/components/ui/badge";
import type { ShipmentStatus } from "@/data/shipments";

// Status colours were picked when the list page shipped.
const styles: Record<ShipmentStatus, string> = {
  booked: "bg-slate-100 text-slate-700 border-slate-200",
  in_transit: "bg-sky-100 text-sky-800 border-sky-200",
  delayed: "bg-amber-100 text-amber-800 border-amber-300",
  delivered: "bg-emerald-100 text-emerald-800 border-emerald-200",
  exception: "bg-red-100 text-red-800 border-red-200",
};

const labels: Record<ShipmentStatus, string> = {
  booked: "Booked",
  in_transit: "In transit",
  delayed: "Delayed",
  delivered: "Delivered",
  exception: "Needs attention",
};

export function StatusBadge({ status }: { status: ShipmentStatus }) {
  return <Badge className={styles[status]}>{labels[status]}</Badge>;
}
