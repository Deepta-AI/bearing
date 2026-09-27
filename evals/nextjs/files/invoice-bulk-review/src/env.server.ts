import "server-only";
import { z } from "zod";

export const env = z
  .object({
    LEDGER_API_URL: z.url().default("http://localhost:8090"),
    LEDGER_API_KEY: z.string().min(1),
    SESSION_SECRET: z.string().min(32),
  })
  .parse(process.env);
