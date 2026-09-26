import { defineConfig } from "vitest/config";

// Integration tests run against the migrated database in DATABASE_URL
// (make db, make migrate, make test-integration). No coverage: the units own it.
export default defineConfig({
  test: {
    include: ["tests/integration/**/*.test.ts"],
    fileParallelism: false,
    testTimeout: 15_000,
  },
});
