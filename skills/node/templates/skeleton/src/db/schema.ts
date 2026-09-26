import { pgTable, serial, timestamp } from "drizzle-orm/pg-core";

// Drizzle schema. Every table lives here (or in a file this one re-exports)
// so drizzle-kit sees all of it. `make migrate-new name=...` diffs this file
// against drizzle/meta and writes the SQL.

/** schemaProbe proves the migration pipeline works. Delete it with the first real table. */
export const schemaProbe = pgTable("schema_probe", {
  id: serial("id").primaryKey(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});
