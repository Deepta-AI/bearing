import type { ScreenSpec } from "@/design/screen";

import { HealthCardView } from "../components/HealthCardView";

// Every state of the health card, from fixtures: the scaffold's example of a
// screen design as code. The design gallery at /__design/S-00 renders it.
// The loading state is the page's Suspense fallback, so it is not a state of
// the card itself.
export const screen: ScreenSpec = {
  id: "S-00",
  name: "API health",
  feature: "health",
  job: "Show whether the API answers, and why not when it does not.",
  states: {
    error: () => <HealthCardView status="error" message="GET /healthz: 503" />,
    success: () => <HealthCardView status="success" health={{ status: "ok", version: "1.2.3" }} />,
  },
};
