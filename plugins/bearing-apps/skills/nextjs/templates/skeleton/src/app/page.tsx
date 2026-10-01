import { Suspense } from "react";

import { env } from "@/env";
import { FeedbackForm } from "@/features/feedback/components/FeedbackForm";
import { HealthCard } from "@/features/health/components/HealthCard";

// The index route. HealthCard fetches on the server without a cache, so it
// runs at request time; under Cache Components that read must sit inside a
// Suspense boundary, and the rest of the page is the prerendered shell.
export default function HomePage() {
  return (
    <div className="mx-auto max-w-5xl space-y-8 px-4 py-8">
      <h1 className="text-2xl font-semibold">{env.NEXT_PUBLIC_APP_NAME}</h1>
      <Suspense
        fallback={
          <p role="status" aria-live="polite" className="text-muted-foreground">
            Checking the API
          </p>
        }
      >
        <HealthCard />
      </Suspense>
      <FeedbackForm />
    </div>
  );
}
