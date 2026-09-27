import { useParams } from "react-router-dom";
import { StatusBadge } from "@/components/StatusBadge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { shipments } from "@/data/shipments";

const time = new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" });

export function ShipmentTrackingPage() {
  const { id } = useParams();
  const s = shipments.find((x) => x.id === id);
  if (!s) {
    return <p>We could not find that shipment. Check the reference and try again.</p>;
  }
  const late = new Date(s.eta) > new Date(s.promisedBy);
  return (
    <section className="grid gap-6 lg:grid-cols-[2fr_1fr]">
      <div className="grid gap-6">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-semibold">{s.reference}</h1>
          <StatusBadge status={s.status} />
        </div>
        <p className="text-muted-foreground">
          {s.origin} to {s.destination}, {s.pallets} pallets, {s.weightKg.toLocaleString("en-IN")} kg
        </p>
        {late && (
          <div role="status" className="rounded-md border border-amber-300 bg-amber-50 p-4 text-amber-900">
            Now expected {time.format(new Date(s.eta))}, after the promised {time.format(new Date(s.promisedBy))}.
            Let the consignee know before they plan unloading.
          </div>
        )}
        {!s.carrierReachable && (
          <div role="alert" className="rounded-md border border-destructive p-4 text-destructive">
            {s.carrier} is not sending updates. The last position may be out of date; call the carrier to confirm.
          </div>
        )}
        <Card>
          <CardHeader>
            <CardTitle>Movement</CardTitle>
          </CardHeader>
          <CardContent>
            {s.events.length === 0 ? (
              <p className="text-muted-foreground">No movement yet. Updates appear here once the truck is loaded.</p>
            ) : (
              <ol className="grid gap-4">
                {s.events.map((e) => (
                  <li key={e.at} className="grid grid-cols-[10rem_1fr] gap-4">
                    <time className="font-mono text-sm text-muted-foreground">{time.format(new Date(e.at))}</time>
                    <span>
                      <strong>{e.place}</strong> {e.note}
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </CardContent>
        </Card>
      </div>
      <aside className="grid content-start gap-4">
        <Card>
          <CardContent className="grid gap-2">
            <span className="text-sm text-muted-foreground">Expected delivery</span>
            <span className="text-xl font-semibold">{time.format(new Date(s.eta))}</span>
            <span className="text-sm text-muted-foreground">Carrier: {s.carrier}</span>
          </CardContent>
        </Card>
        <Button>Notify consignee</Button>
        <Button variant="outline">Copy tracking link</Button>
      </aside>
    </section>
  );
}
