import { defineConfig } from "drizzle-kit";

// drizzle-kit reads the schema from src/db/schema.ts and writes SQL
// migrations into drizzle/. `make migrate-new name=add_invoices` generates,
// `make migrate` applies. DATABASE_URL is needed only to apply.
export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dbCredentials: { url: process.env.DATABASE_URL ?? "postgres://localhost/unset" },
  strict: true,
  verbose: true,
});
