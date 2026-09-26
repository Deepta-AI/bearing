#!/usr/bin/env bash
# tests/unit/vapt_findings.sh: plugins/bearing/skills/vapt-report/scripts/collect_findings.py
# reads the newest claude-security results with their revision stamp and the
# newest gstack /cso report, merges findings at the same file and line
# (higher severity wins, both sources named), fails on a claude-security scan
# of another commit or a /cso report older than --since unless
# --allow-stale, and fails when no scanner report exists.
set -u
. "$(dirname "$0")/../lib/assert.sh"
COL="$KIT/plugins/bearing/skills/vapt-report/scripts/collect_findings.py"

cs() { # cs <root> <sha>: a claude-security report of that commit
  local d="$1/CLAUDE-SECURITY-20260923-101010"; mkdir -p "$d"
  printf '%s\n' \
    '{"id":"F1","title":"IDOR on invoice read","file":"api/invoice.go","line":42,"category":"authz","severity":"HIGH","confidence":"high","exploit_scenario":"GET /invoices/2 as tenant 1","recommendation":"check tenant","cwe_id":"CWE-639","claudeSecurityPluginFindingId":"cs-1"}' \
    '{"id":"F2","title":"Weak header","file":"api/server.go","line":10,"category":"hardening","severity":"LOW","confidence":"medium","exploit_scenario":"","recommendation":"add HSTS","cwe_id":"CWE-693","claudeSecurityPluginFindingId":"cs-2"}' \
    > "$d/CLAUDE-SECURITY-RESULTS.jsonl"
  printf '{"revision":{"commit":"%s"},"verification":{"status":"verified"}}\n' "$2" > "$d/CLAUDE-SECURITY-REVISION-${2:0:12}.json"
}
cso() { # cso <root> <date>: a /cso report
  mkdir -p "$1/.gstack/security-reports"
  printf '{"version":"2.0.0","date":"%s","mode":"comprehensive","scope":"full","findings":[{"id":1,"severity":"CRITICAL","confidence":9,"status":"VERIFIED","category":"Authz","title":"Cross-tenant invoice read","file":"api/invoice.go","line":42,"exploit_scenario":"x","recommendation":"y","verification":"independently verified"},{"id":2,"severity":"MEDIUM","confidence":8,"category":"Secrets","title":"Key in history","file":"config/old.env","line":3,"verification":"self-verified"}]}\n' "$2" \
    > "$1/.gstack/security-reports/2026-09-23-101010.json"
}
SHA=0123456789abcdef0123456789abcdef01234567

t_begin "both scanners merge at the same file and line"
d="$(tmpdir)"; cs "$d" "$SHA"; cso "$d" "2026-09-23T10:10:10Z"
assert_exit 0 python3 "$COL" --root "$d" --commit "$SHA" --since 2026-09-22T00:00:00Z --out "$d/o.json"
assert_contains "$T_OUT" "vapt-findings: 2 sources (claude-security 0123456789ab (verified), /cso 2026-09-23T10:10:10Z), 3 findings (Critical 1, High 0, Medium 1, Low 1), 1 merged duplicates"
assert_eq Critical "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["findings"][0]["severity"])' "$d/o.json")"
assert_contains "$(cat "$d/o.json")" "claude-security cs-1"
assert_contains "$(cat "$d/o.json")" "/cso #1 (confidence 9)"
t_end

t_begin "one scanner is enough"
d="$(tmpdir)"; cso "$d" "2026-09-23T10:10:10Z"
assert_exit 0 python3 "$COL" --root "$d" --out "$d/o.json"
assert_contains "$T_OUT" "1 sources (/cso"
t_end

t_begin "a scan of another commit or an old /cso report is stale"
d="$(tmpdir)"; cs "$d" "$SHA"; cso "$d" "2026-09-01T00:00:00Z"
assert_exit 1 python3 "$COL" --root "$d" --commit fedcba9876543210 --since 2026-09-20T00:00:00Z --out "$d/o.json"
assert_contains "$T_OUT" "claude-security: CLAUDE-SECURITY-20260923-101010/CLAUDE-SECURITY-RESULTS.jsonl is stale (scanned 0123456789ab"
assert_contains "$T_OUT" "/cso: .gstack/security-reports/2026-09-23-101010.json is stale (dated 2026-09-01"
assert_exit 0 python3 "$COL" --root "$d" --commit fedcba9876543210 --since 2026-09-20T00:00:00Z --allow-stale --out "$d/o.json"
assert_contains "$T_OUT" "stale (accepted)"
t_end

t_begin "a missing stamp and a broken line are problems"
d="$(tmpdir)"; cs "$d" "$SHA"; rm "$d"/CLAUDE-SECURITY-*/CLAUDE-SECURITY-REVISION-*.json
printf 'not json\n' >> "$d"/CLAUDE-SECURITY-*/CLAUDE-SECURITY-RESULTS.jsonl
assert_exit 1 python3 "$COL" --root "$d" --out "$d/o.json"
assert_contains "$T_OUT" "no revision stamp"
assert_contains "$T_OUT" "line 3 of"
t_end

t_begin "no scanner report fails"
d="$(tmpdir)"
assert_exit 1 python3 "$COL" --root "$d" --out "$d/o.json"
assert_contains "$T_OUT" "0 scanner reports found; run /cso or claude-security first"
t_end

t_summary
