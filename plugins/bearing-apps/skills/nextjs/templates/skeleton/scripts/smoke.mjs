#!/usr/bin/env node
// smoke: the definition of done's run of what ships. It starts the standalone
// production server from `make build`, drives the checks in
// .scratch/smoke-plan-<id>.txt (one `METHOD /path status` per line; a `base`
// line is ignored, the server is this run's own) or, with no plan, the health
// probe and the home page, and writes .scratch/smoke-<id>.md with the line the
// autopilot dod gate reads: "smoke: N requests checked, F failed". It exits 1
// on any failure or on zero requests checked, and always stops the server.
//
//   node scripts/smoke.mjs [--id TASK-1] [--port 3300]
//
// .env.local, when present, is loaded into the server's environment here and
// never printed. The server binds the hostname the checks request: proxy.ts
// rewrites to absolute URLs built from the request, and Next serves them in
// process only when that hostname is its own (else it proxies them and fails).
import { spawn } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i === -1 ? fallback : args[i + 1];
};
const id = opt("--id", "smoke");
const port = Number(opt("--port", "3300"));
const base = `http://localhost:${port}`;
const root = process.cwd();
const standalone = path.join(root, ".next", "standalone");

if (!existsSync(path.join(standalone, "server.js"))) {
  console.error("smoke: no .next/standalone/server.js; run make build first. 0 requests checked");
  process.exit(1);
}

/** readEnv parses KEY=value lines; values stay in this process and the server's. */
function readEnv(file) {
  if (!existsSync(file)) return {};
  const out = {};
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (m) out[m[1]] = m[2].replace(/^"(.*)"$/, "$1");
  }
  return out;
}

/** plan reads the checks: METHOD /path status per line, # comments and base lines skipped. */
function plan() {
  const file = path.join(root, ".scratch", `smoke-plan-${id}.txt`);
  if (!existsSync(file)) {
    return [
      ["GET", "/api/healthz", 200],
      ["GET", "/", 200],
    ];
  }
  return readFileSync(file, "utf8")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#") && !l.startsWith("base "))
    .map((l) => {
      const [method, p, status] = l.split(/\s+/);
      return [method.toUpperCase(), p, Number(status)];
    });
}

cpSync(path.join(root, ".next", "static"), path.join(standalone, ".next", "static"), {
  recursive: true,
});
if (existsSync(path.join(root, "public"))) {
  cpSync(path.join(root, "public"), path.join(standalone, "public"), { recursive: true });
}

const server = spawn(process.execPath, [path.join(standalone, "server.js")], {
  env: {
    ...process.env,
    ...readEnv(path.join(root, ".env.local")),
    NODE_ENV: "production",
    PORT: String(port),
    HOSTNAME: "localhost",
  },
  stdio: ["ignore", "pipe", "pipe"],
});
let serverLog = "";
server.stdout.on("data", (b) => (serverLog += b));
server.stderr.on("data", (b) => (serverLog += b));

async function waitUp() {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    try {
      if ((await fetch(`${base}/api/healthz`)).ok) return true;
    } catch {
      // not listening yet
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

const rows = [];
let up = false;
try {
  up = await waitUp();
  if (up) {
    for (const [method, p, want] of plan()) {
      let got = 0;
      let note = "";
      try {
        got = (await fetch(`${base}${p}`, { method, redirect: "manual" })).status;
      } catch (e) {
        note = String(e instanceof Error ? e.message : e);
      }
      rows.push({ method, p, want, got, ok: got === want, note });
    }
  }
} finally {
  server.kill("SIGTERM");
}

// A page that renders with an error still answers 200 when React falls back
// to client rendering; the server's own error lines are a failed check.
if (up) {
  const errors = serverLog.split("\n").filter((l) => l.startsWith("⨯")).length;
  rows.push({
    method: "LOG",
    p: "server render errors",
    want: 0,
    got: errors,
    ok: errors === 0,
    note: "",
  });
}
const failed = rows.filter((r) => !r.ok).length;
const line = `smoke: ${rows.length} requests checked, ${failed} failed`;
const table = rows
  .map(
    (r) =>
      `| ${r.ok ? "pass" : "FAIL"} | ${r.method} ${r.p} | ${r.want} | ${r.method === "LOG" ? r.got : r.got || "no answer"} | ${r.note} |`,
  )
  .join("\n");
mkdirSync(path.join(root, ".scratch"), { recursive: true });
const out = path.join(root, ".scratch", `smoke-${id}.md`);
writeFileSync(
  out,
  `# Smoke: ${id}\n\nThe standalone production build on ${base}.\n\n` +
    (up ? "" : "The server never answered /api/healthz within 60 s.\n\n") +
    (up && failed === 0
      ? ""
      : `The server's output (last 4000 characters):\n\n\`\`\`\n${serverLog.slice(-4000)}\n\`\`\`\n\n`) +
    `| Result | Request | Wanted | Got | Note |\n| --- | --- | --- | --- | --- |\n${table}\n\n${line}\n`,
);
console.log(`${line} (${path.relative(root, out)})`);
process.exit(rows.length > 0 && failed === 0 ? 0 : 1);
