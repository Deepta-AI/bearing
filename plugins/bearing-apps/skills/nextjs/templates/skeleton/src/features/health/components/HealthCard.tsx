import { ApiError } from "@/lib/api";

import { fetchHealth } from "../api";
import { HealthCardView, type HealthCardViewProps } from "./HealthCardView";

function describeError(error: unknown): string {
  return error instanceof ApiError ? error.message : "Unexpected error";
}

/**
 * HealthCard is a server component: it fetches on the server and streams
 * its HTML inside the page's Suspense boundary. No client JavaScript ships
 * for it. A failed fetch renders the error state instead of throwing, so
 * the rest of the page still renders.
 */
export async function HealthCard() {
  // The try covers the fetch only; JSX is built outside it, because a
  // render error is an error boundary's job, not a catch block's.
  let props: HealthCardViewProps;
  try {
    props = { status: "success", health: await fetchHealth() };
  } catch (error) {
    props = { status: "error", message: describeError(error) };
  }
  return <HealthCardView {...props} />;
}
