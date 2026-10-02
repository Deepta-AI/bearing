#!/usr/bin/env bash
# tests/unit/next_smoke.sh: the Next.js template's scripts/smoke.mjs. A stand-in
# .next/standalone/server.js (a plain node http server) answers on the port the
# script gives it, so the whole loop runs without a Next build: no build is
# refused with 0 checked; the default checks pass; a plan's checks run and a
# wrong status fails with the evidence written; a render error the server logs
# fails though every status passed.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SMOKE="$KIT/plugins/bearing-apps/skills/nextjs/templates/skeleton/scripts/smoke.mjs"

app() { # app <dir>: a fake build whose server answers / and /api/healthz with 200, else 404
  mkdir -p "$1/.next/standalone" "$1/.next/static"
  cat > "$1/.next/standalone/server.js" <<'JS'
const http = require("node:http");
const host = process.env.HOSTNAME;
http.createServer((req, res) => {
  res.statusCode = req.url === "/" || req.url === "/api/healthz" ? 200 : 404;
  res.end(`host ${host}`);
}).listen(Number(process.env.PORT), host);
JS
}

t_begin "no build is refused and checks nothing"
d="$(tmpdir)"
assert_exit 1 bash -c "cd '$d' && node '$SMOKE' --id T-1 --port 3391"
assert_contains "$T_OUT" "run make build first. 0 requests checked"
t_end

t_begin "with no plan the health probe, the home page and the server log are checked"
d="$(tmpdir)"; app "$d"
assert_exit 0 bash -c "cd '$d' && node '$SMOKE' --id T-1 --port 3392"
assert_contains "$T_OUT" "smoke: 3 requests checked, 0 failed"
assert_contains "$(cat "$d/.scratch/smoke-T-1.md")" "smoke: 3 requests checked, 0 failed"
t_end

t_begin "a plan's wrong status fails and the evidence names it"
d="$(tmpdir)"; app "$d"; mkdir -p "$d/.scratch"
printf 'base http://ignored\nGET / 200\nGET /missing 200\n' > "$d/.scratch/smoke-plan-T-2.txt"
assert_exit 1 bash -c "cd '$d' && node '$SMOKE' --id T-2 --port 3393"
assert_contains "$T_OUT" "smoke: 3 requests checked, 1 failed"
assert_contains "$(cat "$d/.scratch/smoke-T-2.md")" "| FAIL | GET /missing | 200 | 404 |"
t_end

t_begin "a render error in the server's output fails the smoke though every status passed"
d="$(tmpdir)"; app "$d"
printf 'console.error("\u2a2f Error: Couldn\x27t find all resumable slots");\n' >> "$d/.next/standalone/server.js"
assert_exit 1 bash -c "cd '$d' && node '$SMOKE' --id T-3 --port 3394"
assert_contains "$T_OUT" "smoke: 3 requests checked, 1 failed"
assert_contains "$(cat "$d/.scratch/smoke-T-3.md")" "| FAIL | LOG server render errors | 0 | 1 |"
t_end

t_summary
