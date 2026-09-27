import "server-only";
import { z } from "zod";

const schema = z.object({
  API_URL: z.string().url().default("http://localhost:8080"),
  API_TOKEN: z.string().min(1),
  SESSION_SECRET: z.string().min(32),
});

export const env = schema.parse(process.env);
