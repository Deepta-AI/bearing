import path from "node:path";

import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";
import { defineConfig } from "vitest/config";

// Unit tests: jsdom, Testing Library, coverage floors at 80 percent.
// Server components are rendered by awaiting them; `server-only` is aliased
// to an empty module so server-side files import in the test process.
export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  resolve: {
    alias: { "server-only": path.resolve(import.meta.dirname, "src/test/server-only.ts") },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["src/test/setup.ts"],
    include: ["src/**/*.test.{ts,tsx}"],
    env: { API_URL: "http://api.test", NEXT_PUBLIC_APP_NAME: "Test App" },
    restoreMocks: true,
    unstubGlobals: true,
    unstubEnvs: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.{ts,tsx}"],
      exclude: [
        "src/**/*.test.{ts,tsx}",
        "src/**/*.d.ts",
        "src/test/**",
        "src/components/ui/**",
        // Framework wiring, exercised by the build and the e2e suite.
        "src/app/layout.tsx",
        "src/app/page.tsx",
        "src/app/loading.tsx",
        "src/app/global-error.tsx",
        "src/proxy.ts",
        // The design gallery's routes and generated list, exercised by Gallery.test.tsx.
        "src/app/%5F%5Fdesign/**",
        "src/design/screens.generated.ts",
        // Generated with src/components/ui; screen designs are fixtures the
        // design gallery and gallery_check cover, not product logic.
        "src/hooks/use-mobile.ts",
        "src/features/**/screens/**",
      ],
      thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
    },
  },
});
