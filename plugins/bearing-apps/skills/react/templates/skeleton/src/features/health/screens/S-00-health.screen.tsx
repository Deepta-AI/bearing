import type { ScreenSpec } from "@/design/screen";

import { HealthCardView } from "../components/HealthCard";

// Every state of the health card, from fixtures. The design gallery at
// /__design/S-00 renders these inside the real app shell.
export const screen: ScreenSpec = {
  id: "S-00",
  name: "API health",
  feature: "health",
  job: "Show whether the API answers, and let the reader retry when it does not.",
  states: {
    loading: () => <HealthCardView status="pending" />,
    error: () => <HealthCardView status="error" errorMessage="GET /healthz: 503" />,
    success: () => <HealthCardView status="success" data={{ status: "ok", version: "1.2.3" }} />,
  },
};
