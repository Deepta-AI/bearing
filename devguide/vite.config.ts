import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Served at the root of its own Vercel project; DEVGUIDE_BASE is there for a
// host that serves it under a path.
export default defineConfig({
  base: process.env.DEVGUIDE_BASE || "/",
  plugins: [react()],
  build: { outDir: "dist", sourcemap: false, chunkSizeWarningLimit: 1600 },
});
