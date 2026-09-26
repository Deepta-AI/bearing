// Route-level pending UI: shown while page.tsx and its data are on the way.
export default function Loading() {
  return (
    <p role="status" aria-live="polite" className="text-muted-foreground">
      Loading
    </p>
  );
}
