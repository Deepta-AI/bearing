import { z } from "zod";

const EnvSchema = z.object({
  VITE_API_BASE_URL: z.url(),
});

export const env = EnvSchema.parse(import.meta.env);
