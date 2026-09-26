"use client";

// The boundary of last resort: the root layout itself failed, so this
// renders its own html and body. Keep it dependency-free; globals.css may
// not have loaded.
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body>
        <main role="alert" style={{ fontFamily: "system-ui", padding: "2rem" }}>
          <h1>Something went wrong</h1>
          <p>{error.digest !== undefined ? `Reference ${error.digest}` : error.message}</p>
          <button type="button" onClick={reset}>
            Try again
          </button>
        </main>
      </body>
    </html>
  );
}
