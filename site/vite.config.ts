import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// GitLab Pages serves the site under /<project>/ unless the project uses a
// unique domain; CI passes the path in HANDBOOK_BASE. Locally it is "/".
export default defineConfig({
  base: process.env.HANDBOOK_BASE || "/",
  plugins: [react()],
  build: { outDir: "dist", sourcemap: false, chunkSizeWarningLimit: 900 },
});
