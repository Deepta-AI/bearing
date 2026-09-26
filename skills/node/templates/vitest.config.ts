import { defineConfig } from "vitest/config";

// Unit tests: no database, no network. Integration tests have their own
// config (vitest.integration.config.ts) because they need DATABASE_URL.
export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
    restoreMocks: true,
    unstubEnvs: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      // server.ts is wiring, exercised by make dev and the image, not by units.
      exclude: ["src/**/*.test.ts", "src/server.ts"],
      thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
    },
  },
});
