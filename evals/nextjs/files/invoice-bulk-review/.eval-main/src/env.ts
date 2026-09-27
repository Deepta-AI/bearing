import { z } from "zod";

// Public values, inlined into the browser bundle at build time.
export const publicEnv = z
  .object({
    NEXT_PUBLIC_SUPPORT_EMAIL: z.email(),
  })
  .parse({
    NEXT_PUBLIC_SUPPORT_EMAIL: process.env.NEXT_PUBLIC_SUPPORT_EMAIL,
  });
