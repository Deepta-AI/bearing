import { z } from "zod";

// Public values, inlined into the browser bundle at build time.
export const publicEnv = z
  .object({
    NEXT_PUBLIC_SUPPORT_EMAIL: z.email(),
    NEXT_PUBLIC_LEDGER_API_URL: z.url(),
    NEXT_PUBLIC_LEDGER_API_KEY: z.string().min(1),
  })
  .parse({
    NEXT_PUBLIC_SUPPORT_EMAIL: process.env.NEXT_PUBLIC_SUPPORT_EMAIL,
    NEXT_PUBLIC_LEDGER_API_URL: process.env.NEXT_PUBLIC_LEDGER_API_URL,
    NEXT_PUBLIC_LEDGER_API_KEY: process.env.NEXT_PUBLIC_LEDGER_API_KEY,
  });
