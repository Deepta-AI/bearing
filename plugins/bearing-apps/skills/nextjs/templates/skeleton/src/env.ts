import { z } from "zod";

// Public configuration, safe in the client bundle. Next inlines a
// NEXT_PUBLIC_ variable only where it is referenced by its full name, so
// each one is named here explicitly. Nothing secret belongs in this file;
// server-only values live in src/env.server.ts.
const publicSchema = z.object({
  NEXT_PUBLIC_APP_NAME: z.string().min(1).default("__REPO_NAME__"),
});

export type PublicEnv = z.infer<typeof publicSchema>;

function present(value: string | undefined): string | undefined {
  return value === undefined || value === "" ? undefined : value;
}

export function parsePublicEnv(source: Record<string, string | undefined>): PublicEnv {
  return publicSchema.parse({
    NEXT_PUBLIC_APP_NAME: present(source.NEXT_PUBLIC_APP_NAME),
  });
}

export const env: PublicEnv = parsePublicEnv({
  NEXT_PUBLIC_APP_NAME: process.env.NEXT_PUBLIC_APP_NAME,
});
