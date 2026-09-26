import type { NextConfig } from "next";

// Standalone output: `next build` writes a self-contained server into
// .next/standalone, which is what the Dockerfile ships. No secrets here;
// runtime configuration comes from the environment through src/env.server.ts.
//
// cacheComponents: every route is dynamic by default and caching is opt-in
// with "use cache" plus cacheLife and cacheTag. Route segment configs
// (`dynamic`, `revalidate`, `fetchCache`) are errors under it.
const nextConfig: NextConfig = {
  output: "standalone",
  cacheComponents: true,
  // `next dev` would otherwise write its own agent-rules block into
  // AGENTS.md, which this standard owns. The version-matched docs it points
  // at are in node_modules/next/dist/docs; the nextjs skill says so.
  agentRules: false,
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    // Add the hosts the app serves images from; an unlisted host fails loudly.
    remotePatterns: [],
  },
  logging: {
    fetches: { fullUrl: process.env.NODE_ENV !== "production" },
  },
};

export default nextConfig;
