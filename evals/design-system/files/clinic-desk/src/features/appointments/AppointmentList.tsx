import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { formatSlot, statusLabel } from "@/lib/slots.js";
import { DayLoad } from "./DayLoad";

const today = [
  { id: "a1", patient: "R. Sharma", start: "2026-09-01T09:00:00Z", minutes: 30, status: "checked_in" },
  { id: "a2", patient: "M. Iyer", start: "2026-09-01T09:30:00Z", minutes: 15, status: "booked" },
  { id: "a3", patient: "S. Khan", start: "2026-09-01T10:00:00Z", minutes: 30, status: "no_show" },
];

export function AppointmentList() {
  return (
    <Card>
      <CardHeader>
        <h2 className="text-lg font-semibold">Today</h2>
        <p className="text-sm text-muted-foreground">{today.length} appointments</p>
      </CardHeader>
      <CardContent className="space-y-3">
        <DayLoad booked={today.length} capacity={12} />
        <div className="flex justify-between rounded-md bg-muted px-4 py-2 text-xs font-medium text-muted-foreground">
          <span>Patient and time</span>
          <span>Action</span>
        </div>
        {today.map((a) => (
          <div key={a.id} className="flex items-center justify-between rounded-md border px-4 py-3">
            <div>
              <p className="font-medium">{a.patient}</p>
              <p className="text-sm text-muted-foreground">
                {formatSlot(a.start, a.minutes)} . {statusLabel(a.status)}
              </p>
            </div>
            <div className="flex gap-2">
              {a.status === "booked" && (
                <Button size="sm" variant="destructive">
                  Mark no-show
                </Button>
              )}
              <Button size="sm">Check in</Button>
            </div>
          </div>
        ))}
        <a href="/schedule" className="text-sm text-primary underline-offset-4 hover:underline">
          Open the full schedule
        </a>
      </CardContent>
    </Card>
  );
}
