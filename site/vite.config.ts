import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { sectionsPlugin } from "../ui/sections-plugin.mjs";

// GitLab Pages serves the site under /<project>/ unless the project uses a
// unique domain; CI passes the path in HANDBOOK_BASE. Locally it is "/".
// The design both sites share lives in ../ui, imported as @ui; react and the
// router resolve from this app's node_modules.
export default defineConfig({
  base: process.env.HANDBOOK_BASE || "/",
  plugins: [react(), sectionsPlugin(fileURLToPath(new URL(".", import.meta.url)))],
  resolve: {
    alias: { "@ui": fileURLToPath(new URL("../ui", import.meta.url)) },
    dedupe: ["react", "react-dom", "react-router"],
  },
  server: { fs: { allow: [".."] } },
  build: { outDir: "dist", sourcemap: false, chunkSizeWarningLimit: 900 },
});
