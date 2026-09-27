// How full today's book is, drawn as a bar in the brand colour.
export function DayLoad({ booked, capacity }: { booked: number; capacity: number }) {
  const percent = Math.min(100, Math.round((booked / capacity) * 100));
  return (
    <div className="space-y-1">
      <p className="text-sm text-muted-foreground">
        {booked} of {capacity} slots booked
      </p>
      <div className="h-2 w-full rounded-full" style={{ backgroundColor: "hsl(var(--primary) / 0.15)" }}>
        <div className="h-2 rounded-full" style={{ width: `${percent}%`, backgroundColor: "hsl(var(--primary))" }} />
      </div>
    </div>
  );
}
