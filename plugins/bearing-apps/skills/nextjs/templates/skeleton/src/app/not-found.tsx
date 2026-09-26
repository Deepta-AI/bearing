import Link from "next/link";

/** NotFound answers any path the app does not know, and `notFound()` calls. */
export default function NotFound() {
  return (
    <section aria-labelledby="not-found-heading">
      <h1 id="not-found-heading" className="text-2xl font-semibold">
        Page not found
      </h1>
      <p className="mt-2 text-muted-foreground">
        <Link href="/" className="underline">
          Back to the start
        </Link>
      </p>
    </section>
  );
}
