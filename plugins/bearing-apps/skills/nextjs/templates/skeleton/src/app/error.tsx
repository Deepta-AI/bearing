"use client";

import { useEffect } from "react";

import { Button } from "@/components/ui/button";

interface ErrorPageProps {
  error: Error & { digest?: string };
  reset: () => void;
}

/**
 * Route error boundary: a page or a server component under this segment
 * threw. The layout stays; reset re-renders the segment. In production the
 * message is generic and `digest` is the key to the server log.
 */
export default function ErrorPage({ error, reset }: ErrorPageProps) {
  useEffect(() => {
    // Wire this to the error reporter; the server has already logged it.
    console.error(error);
  }, [error]);

  return (
    <section role="alert" aria-labelledby="error-heading">
      <h1 id="error-heading" className="text-2xl font-semibold">
        This page could not load
      </h1>
      <p className="mt-2 text-muted-foreground">
        {error.digest !== undefined ? `Reference ${error.digest}` : error.message}
      </p>
      <Button type="button" className="mt-4" onClick={reset}>
        Try again
      </Button>
    </section>
  );
}
