import { Link } from "react-router-dom";
import { StatusBadge } from "@/components/StatusBadge";
import { shipments } from "@/data/shipments";

export function ShipmentsPage() {
  return (
    <section>
      <h1 className="mb-6 text-2xl font-semibold">Open shipments</h1>
      <table className="w-full text-sm">
        <thead className="text-left text-muted-foreground">
          <tr>
            <th className="py-2">Reference</th>
            <th>Route</th>
            <th>Carrier</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {shipments.map((s) => (
            <tr key={s.id} className="border-t">
              <td className="py-3 font-mono">
                <Link to={`/shipments/${s.id}`}>{s.reference}</Link>
              </td>
              <td>
                {s.origin} to {s.destination}
              </td>
              <td>{s.carrier}</td>
              <td>
                <StatusBadge status={s.status} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
