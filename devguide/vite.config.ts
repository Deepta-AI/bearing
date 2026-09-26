import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { sectionsPlugin } from "../ui/sections-plugin.mjs";

// Served at the root of its own Vercel project; DEVGUIDE_BASE is there for a
// host that serves it under a path. The design both sites share lives in
// ../ui, imported as @ui; react and the router resolve from this app.
export default defineConfig({
  base: process.env.DEVGUIDE_BASE || "/",
  plugins: [react(), sectionsPlugin(fileURLToPath(new URL(".", import.meta.url)))],
  resolve: {
    alias: { "@ui": fileURLToPath(new URL("../ui", import.meta.url)) },
    dedupe: ["react", "react-dom", "react-router"],
  },
  server: { fs: { allow: [".."] } },
  build: { outDir: "dist", sourcemap: false, chunkSizeWarningLimit: 1600 },
});
