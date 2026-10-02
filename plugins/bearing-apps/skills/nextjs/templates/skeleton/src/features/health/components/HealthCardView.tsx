import type { Health } from "../schemas";

export type HealthCardViewProps =
  { status: "success"; health: Health } | { status: "error"; message: string };

/**
 * HealthCardView draws one state of the card from props alone, so the
 * design gallery (S-00) shows every state from fixtures and the page
 * renders the same component with live data.
 */
export function HealthCardView(props: HealthCardViewProps) {
  const content =
    props.status === "success" ? (
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
        <dt className="text-muted-foreground">Status</dt>
        <dd className="font-medium">{props.health.status}</dd>
        <dt className="text-muted-foreground">Version</dt>
        <dd className="font-medium">{props.health.version ?? "unknown"}</dd>
      </dl>
    ) : (
      <p className="text-destructive">{props.message}</p>
    );

  return (
    <section
      aria-labelledby="health-heading"
      className="rounded-lg border bg-card p-6 text-card-foreground shadow-sm"
    >
      <h2 id="health-heading" className="text-lg font-semibold">
        API health
      </h2>
      <div role="status" aria-live="polite" className="mt-2 text-sm">
        {content}
      </div>
    </section>
  );
}
