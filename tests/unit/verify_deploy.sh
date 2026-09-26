#!/usr/bin/env bash
# tests/unit/verify_deploy.sh: verify-deploy's verify_deploy.py reads one
# environment from docs/environments.md and checks it in order against a
# local server: readiness, health, version, smoke. It passes only when every
# check passes and the deployed commit matches --expect; it fails on a
# version mismatch, a readiness 503 (after its retries), an environment with
# zero checks and a missing environment, and prints its count every time. A
# 503 that recovers inside the retries passes. The report file carries the
# table and the summary line. The server is killed on exit.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SCRIPT="$KIT/plugins/bearing/skills/verify-deploy/scripts/verify_deploy.py"
COMMIT=3f9c2ab71d04e5c8a9b6f1e2d3c4b5a697887766
# A proxy from the environment (a sandbox sets one) must not carry loopback.
no_proxy="127.0.0.1,localhost${no_proxy:+,$no_proxy}"; NO_PROXY="$no_proxy"; export no_proxy NO_PROXY

W="$(tmpdir)"
PID=''
stop_server() { [ -z "$PID" ] || kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; PID=''; }
trap 'stop_server; _t_cleanup' EXIT

# The server: /readyz answers 503 while $W/unready exists, and once more
# while $W/unready-once exists (the file is removed on that answer).
cat > "$W/server.py" <<'PY'
import http.server, json, os, socketserver, sys
state = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass
    def send(self, code, body, ctype="text/plain"):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.send_header("X-App-Version", "v2.4.0")
        self.end_headers()
        self.wfile.write(b)
    def do_GET(self):
        if self.path == "/readyz":
            once = os.path.join(state, "unready-once")
            if os.path.exists(once):
                os.remove(once)
                return self.send(503, "db: fail")
            if os.path.exists(os.path.join(state, "unready")):
                return self.send(503, "db: fail")
            return self.send(200, "ok")
        if self.path == "/healthz":
            return self.send(200, "ok")
        if self.path == "/version":
            return self.send(200, json.dumps({"build": {"commit": sys.argv[2]}}), "application/json")
        if self.path == "/":
            return self.send(200, "<html><title>Checkout</title><h1>Welcome to Checkout</h1></html>", "text/html")
        if self.path == "/old":
            self.send_response(302)
            self.send_header("Location", "/")
            self.end_headers()
            return
        return self.send(404, "not found")
# HTTPServer.server_bind does a reverse lookup (socket.getfqdn) that can
# stall for many seconds on a macOS runner; the name is never used here.
class S(http.server.HTTPServer):
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
s = S(("127.0.0.1", 0), H)
open(os.path.join(state, "port.tmp"), "w").write(str(s.server_address[1]))
os.rename(os.path.join(state, "port.tmp"), os.path.join(state, "port"))
s.serve_forever()
PY
python3 "$W/server.py" "$W" "$COMMIT" &
PID=$!
i=0
while [ ! -f "$W/port" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
PORT="$(cat "$W/port" 2>/dev/null || true)"
[ -n "$PORT" ] || { echo "FAIL verify_deploy.sh: the test server did not start" >&2; exit 1; }
BASE="http://127.0.0.1:$PORT"

cat > "$W/environments.md" <<MD
# Environments

<!-- guidance: a comment's table is not read
| Key | Value |
| --- | --- |
| Health path | /nothing |
-->

## qa

| Key | Value |
| --- | --- |
| Product URL | $BASE |
| API base URL | $BASE |
| Health path | /healthz |
| Readiness path | /readyz |
| Version path | /version |
| Version field | json:build.commit |
| Owner | checkout-team |
| Rollback | Re-run the deploy job of the previous tag's pipeline in GitLab. |
| Synthetic suite | - |

| Smoke check | Base | Path | Expect | Contains |
| --- | --- | --- | --- | --- |
| home page | product | / | 200 | <title>Checkout</title> |
| old link redirects | product | /old | 200 | Welcome to Checkout |
| unfilled row | api | <a path> | 200 | - |

## staging

| Key | Value |
| --- | --- |
| Product URL | $BASE |
| API base URL | - |
| Health path | /healthz |
| Readiness path | - |
| Version path | / |
| Version field | header:X-App-Version |
| Owner | checkout-team |
| Rollback | Promote the previous image in Argo CD. |

## prod

| Key | Value |
| --- | --- |
| Product URL | $BASE |
| Health path | - |
| Readiness path | <path> |
| Version path | |
| Rollback | Ask the on-call lead. |
MD

run() { # run <args...>: the script against the fixture, report into $W/out
  assert_exit "$1" python3 "$SCRIPT" --file "$W/environments.md" --out "$W/out" --timeout 3 "${@:2}"
}

t_begin "every check passes with the right commit, a short prefix too"
run 0 --env qa --expect "$COMMIT"
assert_contains "$T_OUT" "pass readiness $BASE/readyz"
assert_contains "$T_OUT" "pass smoke: old link redirects $BASE/old"
assert_contains "$T_OUT" "verify: 5 checks, 0 failed (env qa, deployed $COMMIT)"
assert_not_contains "$T_OUT" "unfilled row"
run 0 --env qa --expect 3f9c2ab
assert_contains "$T_OUT" "verify: 5 checks, 0 failed (env qa, deployed $COMMIT)"
t_end

t_begin "the checks run in order: readiness, health, version, smoke"
run 0 --env qa
order="$(printf '%s\n' "$T_OUT" | grep -E '^(pass|FAIL) ' | awk '{print $2}' | tr '\n' ' ')"
assert_eq "readiness health version smoke: smoke: " "$order" "check order"
t_end

t_begin "a version mismatch fails, and a prefix under 7 characters never matches"
run 1 --env qa --expect 9999999
assert_contains "$T_OUT" "FAIL version $BASE/version: expected 200, json:build.commit = 9999999"
assert_contains "$T_OUT" "verify: 5 checks, 1 failed (env qa, deployed $COMMIT)"
assert_contains "$T_OUT" "rollback (the engineer's call): Re-run the deploy job"
run 1 --env qa --expect 3f9c2a
assert_contains "$T_OUT" "verify: 5 checks, 1 failed"
t_end

t_begin "a tag matches the version header exactly"
run 0 --env staging --expect v2.4.0
assert_contains "$T_OUT" "verify: 2 checks, 0 failed (env staging, deployed v2.4.0)"
run 1 --env staging --expect v2.4
assert_contains "$T_OUT" "verify: 2 checks, 1 failed (env staging, deployed v2.4.0)"
t_end

t_begin "readiness 503 fails; a 503 that recovers inside the retries passes"
: > "$W/unready"
run 1 --env qa --retries 0
assert_contains "$T_OUT" "FAIL readiness $BASE/readyz: expected 200; got 503"
assert_contains "$T_OUT" "verify: 5 checks, 1 failed (env qa"
rm -f "$W/unready"
: > "$W/unready-once"
run 0 --env qa --retries 1
assert_contains "$T_OUT" "verify: 5 checks, 0 failed"
t_end

t_begin "an environment with zero checks fails and prints its count"
run 1 --env prod
assert_contains "$T_OUT" "defines 0 checks"
assert_contains "$T_OUT" "verify: 0 checks, 0 failed (env prod, deployed unknown)"
run 1 --env prod --expect v1.0.0
assert_contains "$T_OUT" "no Version path in the file to compare --expect with"
assert_contains "$T_OUT" "verify: 1 checks, 1 failed (env prod"
t_end

t_begin "a missing environment, a missing file, credentials in a URL and a non-http URL fail"
run 1 --env uat
assert_contains "$T_OUT" "no '## uat' section"
assert_contains "$T_OUT" "verify: 0 checks, 0 failed (env uat, deployed unknown)"
assert_exit 1 python3 "$SCRIPT" --env qa --file "$W/nope.md" --out "$W/out"
assert_contains "$T_OUT" "not found"
sed "s#| Product URL | $BASE |#| Product URL | http://probe:x@127.0.0.1:$PORT |#" "$W/environments.md" > "$W/creds.md"
assert_exit 1 python3 "$SCRIPT" --env qa --file "$W/creds.md" --out "$W/out"
assert_contains "$T_OUT" "carries credentials"
sed "s#| Product URL | $BASE |#| Product URL | file:///etc |#" "$W/environments.md" > "$W/scheme.md"
assert_exit 1 python3 "$SCRIPT" --env qa --file "$W/scheme.md" --out "$W/out"
assert_contains "$T_OUT" "is not an http or https URL"
t_end

t_begin "a connection error fails without hanging"
sed "s#$BASE#http://127.0.0.1:1#g" "$W/environments.md" > "$W/down.md"
assert_exit 1 python3 "$SCRIPT" --env staging --file "$W/down.md" --out "$W/out" --timeout 2 --retries 0
assert_contains "$T_OUT" "connection error"
assert_contains "$T_OUT" "verify: 2 checks, 2 failed (env staging, deployed unknown)"
t_end

t_begin "usage errors exit 2"
assert_exit 2 python3 "$SCRIPT"
assert_exit 2 python3 "$SCRIPT" --env qa --retries -1
t_end

t_begin "the report is written with the table, the verdict and the summary line"
rm -rf "$W/out"
run 1 --env qa --expect 9999999
report="$(ls "$W"/out/verify-qa-*.md 2>/dev/null | head -1)"
assert_file "$report"
body="$(cat "$report" 2>/dev/null)"
assert_contains "$body" "| Check | URL | Expected | Got | ms | Result |"
assert_contains "$body" "| readiness | $BASE/readyz | 200 | 200 |"
assert_contains "$body" "Verdict: fail (1 of 5 checks failed)"
assert_contains "$body" "Rollback (the engineer decides and acts): Re-run the deploy job"
assert_contains "$body" "verify: 5 checks, 1 failed (env qa, deployed $COMMIT)"
case "${report##*/}" in verify-qa-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z.md) ok=yes;; *) ok=no;; esac
assert_eq yes "$ok" "report name is verify-<env>-<UTC date and time>.md"
t_end

stop_server
t_summary
