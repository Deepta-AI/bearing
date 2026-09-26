#!/usr/bin/env bash
# tests/unit/runbook_check.sh: plugins/bearing/bin/brg-runbook-check counts alert rules from
# the files and passes only when every one links to a runbook that exists
# under docs/runbooks/. It fails, with the reason, on a rule with no
# runbook_url, on a URL whose runbook is not on disk, on an unroutable rule
# under --paging, and on empty input (no rule file, zero alerts). It parses
# the kit's own alerts template, and the template's commented sketch in
# health-checks counts nothing.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/bin/brg-runbook-check"

# fixture <dir>: two rule files, block and flow style, three runbooks.
fixture() {
  mkdir -p "$1/monitoring/alerts" "$1/docs/runbooks"
  cat > "$1/monitoring/alerts/api.yaml" <<'YAML'
groups:
  - name: api.availability
    rules:
      # - alert: CommentedOut
      #   annotations: { runbook_url: nowhere/CommentedOut.md }
      - alert: ApiErrorBudgetBurnFast
        expr: |
          sum(rate(errors[5m])) > 0.01
        for: 2m
        labels:
          severity: page
        annotations:
          summary: "burning"
          runbook_url: https://gitlab.example.com/g/api/-/blob/main/docs/runbooks/ApiErrorBudgetBurnFast.md
      - record: api:errors:rate5m
        expr: sum(rate(errors[5m]))
      - alert: ApiLatencyHigh
        expr: latency > 0.8
        labels: { severity: ticket, service: api }
        annotations: { summary: "slow", runbook_url: "docs/runbooks/ApiLatencyHigh.md" }
YAML
  cat > "$1/monitoring/alerts/api-health.yml" <<'YAML'
groups:
  - name: api.health
    rules:
      - alert: ApiReadinessFailing
        expr: probe_success == 0
        labels:
          severity: critical
        annotations:
          runbook_url: 'https://runbooks.example.com/ApiReadinessFailing?from=alert'
YAML
  for r in ApiErrorBudgetBurnFast ApiLatencyHigh ApiReadinessFailing; do printf '# %s\n' "$r" > "$1/docs/runbooks/$r.md"; done
}

t_begin "every alert with an existing runbook passes with its counts"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 bash "$CHK" --root "$d"
assert_contains "$T_OUT" "runbook-check: 3 alerts, 3 with runbooks, 0 missing"
assert_not_contains "$T_OUT" "CommentedOut"
assert_not_contains "$T_OUT" "problem:"
t_end

t_begin "a rule without a runbook_url annotation is missing"
d="$(tmpdir)/noann"; fixture "$d"
sed -i.bak '/runbook_url: .ApiReadinessFailing/d; /runbook_url: .https:\/\/runbooks/d' "$d/monitoring/alerts/api-health.yml"
assert_exit 1 bash "$CHK" --root "$d"
assert_contains "$T_OUT" "ApiReadinessFailing: no runbook_url annotation (runbook ApiReadinessFailing)"
assert_contains "$T_OUT" "runbook-check: 3 alerts, 2 with runbooks, 1 missing"
t_end

t_begin "a runbook_url whose file is not on disk is missing"
d="$(tmpdir)/nofile"; fixture "$d"
rm "$d/docs/runbooks/ApiErrorBudgetBurnFast.md" "$d/docs/runbooks/ApiLatencyHigh.md"
assert_exit 1 bash "$CHK" --root "$d"
assert_contains "$T_OUT" "ApiErrorBudgetBurnFast: runbook_url https://gitlab.example.com"
assert_contains "$T_OUT" "ApiLatencyHigh: runbook_url docs/runbooks/ApiLatencyHigh.md resolves to no file"
assert_contains "$T_OUT" "runbook-check: 3 alerts, 1 with runbooks, 2 missing"
t_end

t_begin "a path relative to the rule file resolves"
d="$(tmpdir)/rel"; fixture "$d"
sed -i.bak 's#runbook_url: "docs/runbooks/ApiLatencyHigh.md"#runbook_url: "../../docs/runbooks/ApiLatencyHigh.md"#' "$d/monitoring/alerts/api.yaml"
assert_exit 0 bash "$CHK" --root "$d" "$d/monitoring/alerts/api.yaml"
assert_contains "$T_OUT" "runbook-check: 2 alerts, 2 with runbooks, 0 missing"
t_end

t_begin "--paging checks paging rules only and fails an unroutable rule"
d="$(tmpdir)/paging"; fixture "$d"
rm "$d/docs/runbooks/ApiLatencyHigh.md"
assert_exit 0 bash "$CHK" --root "$d" --paging
assert_contains "$T_OUT" "runbook-check: 2 alerts, 2 with runbooks, 0 missing"
assert_contains "$T_OUT" "runbook-check: 3 rules read from 2 files, 0 unroutable"
sed -i.bak 's/labels: { severity: ticket, service: api }/labels: { service: api }/' "$d/monitoring/alerts/api.yaml"
assert_exit 1 bash "$CHK" --root "$d" --paging
assert_contains "$T_OUT" "ApiLatencyHigh: no severity label, unroutable"
assert_contains "$T_OUT" "1 unroutable"
t_end

t_begin "the kit's alerts template parses to five alerts"
d="$(tmpdir)/tpl"; mkdir -p "$d/docs/runbooks"
for r in ErrorBudgetBurnFast ErrorBudgetBurnSlow LatencyP95High NoTraffic TargetDown; do : > "$d/docs/runbooks/__SERVICE__$r.md"; done
assert_exit 0 bash "$CHK" --root "$d" "$KIT/plugins/bearing/skills/observability/templates/alerts.yaml"
assert_contains "$T_OUT" "runbook-check: 5 alerts, 5 with runbooks, 0 missing"
t_end

t_begin "no rule file, a missing path, zero alerts and zero paging alerts fail"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 bash "$CHK" --root "$d"
assert_contains "$T_OUT" "0 rule files read, nothing checked"
assert_exit 1 bash "$CHK" --root "$d" "$d/nope.yaml"
assert_contains "$T_OUT" "no such rule file or directory"
assert_exit 1 bash "$CHK" --root "$d" "$KIT/plugins/bearing/skills/health-checks/templates/blackbox.yml"
assert_contains "$T_OUT" "runbook-check: 0 alerts, 0 with runbooks, 0 missing"
assert_contains "$T_OUT" "nothing checked"
fixture "$d"
assert_exit 1 bash "$CHK" --root "$d" "$d/monitoring/alerts" "$d/typo.yaml"
assert_contains "$T_OUT" "runbook-check: 3 alerts, 3 with runbooks, 0 missing"
sed -i.bak 's/severity: page/severity: ticket/; s/severity: critical/severity: ticket/' "$d/monitoring/alerts/api.yaml" "$d/monitoring/alerts/api-health.yml"
assert_exit 1 bash "$CHK" --root "$d" --paging
assert_contains "$T_OUT" "0 paging alerts in 2 rule files, nothing checked"
t_end

t_summary
