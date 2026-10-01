#!/usr/bin/env bash
# tests/unit/hld_arch_check.sh: plugins/bearing/skills/high-level-design/scripts/arch_check.py passes a
# complete architecture set and fails on a section with no risks, nothing
# deliberately left out, an ungraded or unsourced finding, Approved with an
# open BLOCKER or an open conflict, an ADR missing from the index, a bad
# reversibility, a conflict with no Settled by, too few tenets or a tenet with
# no breach, a repo plan with a wrong name, path or stack, and empty input.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/high-level-design/scripts/arch_check.py"

risks() { printf '\n**Risks this leaves open**\n\n- %s\n' "$1"; }

# fixture <dir>: a repository holding a passing HLD, tenets, decisions index and repo plan.
fixture() {
  local d="$1" i
  mkdir -p "$d/docs/design" "$d/docs/architecture" "$d/docs/adr"
  printf '# ADR-0001: Use Postgres\n' > "$d/docs/adr/0001-use-postgres.md"
  printf '# ADR-0002: Use an outbox\n' > "$d/docs/adr/0002-use-an-outbox.md"
  { printf '# High Level Design: orders\n\n- Status: Draft\n\n## Summary\n\nOne service, one Postgres.\n\n'
    printf 'Diagram: docs/architecture/diagrams/Shop_SystemArchitecture_v1.svg\n\n## What gets built\n\n'
    printf '| Component | Kind | Stack | Responsibility | Repository |\n| --- | --- | --- | --- | --- |\n'
    printf '| Api | backend | Go | orders | ShopApi |\n| Web | frontend | React | storefront | existing: shop-web |\n\n'
    printf '## 1. Goal and non-goals\n\nGoal.\n\n## 3. Architecture\n\nText.\n'; risks "one process"
    printf '\n## 4. Data\n\nText.\n'; risks "no purge"
    printf '\n## 6. External integrations\n\nPayments.\n\n### Deliberately not integrated\n\n- No analytics SDK: privacy.\n'; risks "provider outage"
    printf '\n## 8. Scaling and limits\n\n120/min.\n'; risks "untested"
    printf '\n## 9. Security and privacy\n\nText.\n'; risks "token theft"
    printf '\n## 10. Observability\n\nText.\n'; risks "no aggregator"
    printf '\n## 11. Analytics\n\nText.\n'; risks "lower bound"
    printf '\n## 12. Rollout and rollback\n\nText.\n'; risks "manual rollback"
    printf '\n## 13. Outside the standard stack\n\nNone: every technology is a catalogue default.\n'
    printf '\n## 14. Repository plan\n\nSee repo-plan.json.\n'
    printf '\n## 16. What the review found\n\nReviewed by: critic, 2026-09-25\n\n'
    printf '### MAJOR: endpoint named two ways\n\nADR-0002 and section 11 disagree.\nConflicts with: ADR-0002, section 11\nFix: use ADR-0002 names.\nStatus: fixed (section 11)\n'
  } > "$d/docs/design/orders-hld.md"
  { printf '# System design tenets: Shop\n\n'
    for i in 1 2 3 4 5; do printf '## %s. Tenet %s\n\n**Rule %s holds.**\n\nWhy.\n\n_A breach looks like:_ an MR that breaks it.\n\n' "$i" "$i" "$i"; done
  } > "$d/docs/architecture/tenets.md"
  { printf '# Architecture decisions: Shop\n\n## Decisions\n\n| Id | Title | Area | Status | Reversibility |\n| --- | --- | --- | --- | --- |\n'
    printf '| ADR-0001 | Use Postgres | database | Accepted | irreversible: every table moves |\n'
    printf '| ADR-0002 | Use an outbox | messaging | Proposed | cheap: one worker |\n\n'
    printf '## Conflicts that were settled\n\n### Whether uploads go through the API\n\n**Between:** US-02-004, attachments, ADR-0002\n\n'
    printf '**Decision.** Through the API.\n\n**Why.** The type is sniffed at write time.\n\n**Settled by:** Architect\n\n**What now has to change to match:**\n\n- ADR-0002 consequences\n'
  } > "$d/docs/architecture/decisions.md"
  cat > "$d/docs/architecture/repo-plan.json" <<'JSON'
{"project": "Shop", "group": "Shop", "repos": [
  {"name": "ShopApi", "git_path": "Shop/Server/ShopApi", "stack": "go-api", "responsibility": "orders"},
  {"name": "ShopClient", "git_path": "Shop/Client/ShopClient", "stack": "react-web", "responsibility": "clients",
   "apps": [{"path": "apps/web", "name": "Web", "for": "customers"}]}]}
JSON
}
run() { (cd "$1" && python3 "$CHK"); }
edit() { python3 -c 'import sys;p,a,b=sys.argv[1:];s=open(p).read();assert a in s,a;open(p,"w").write(s.replace(a,b))' "$@"; }

t_begin "a complete architecture set passes with its counts"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "arch-check: 1 HLD (0 Approved), 2 components, 2 repos, 5 tenets, 2 indexed ADRs of 2 files, 1 conflicts (0 open), 8 risks, findings BLOCKER 0 (open 0), MAJOR 1, MINOR 0, NIT 0; 0 problems"
assert_contains "$T_OUT" "Gate: passed"
t_end

t_begin "a section with no risks and nothing deliberately left out fail"
d="$(tmpdir)/risks"; fixture "$d"
edit "$d/docs/design/orders-hld.md" "- token theft" "token theft, prose only"
edit "$d/docs/design/orders-hld.md" "- No analytics SDK: privacy." "Nothing."
assert_exit 1 run "$d"
assert_contains "$T_OUT" "'9. Security and privacy' has no 'Risks this leaves open' bullets"
assert_contains "$T_OUT" "lists nothing under 'Deliberately not integrated'"
t_end

t_begin "an ungraded finding, one with no Fix, and Approved with an open BLOCKER fail"
d="$(tmpdir)/review"; fixture "$d"
edit "$d/docs/design/orders-hld.md" "- Status: Draft" "- Status: Approved"
mkdir -p "$d/docs/architecture/diagrams"; : > "$d/docs/architecture/diagrams/Shop_SystemArchitecture_v1.svg"
printf '\n### BLOCKER: secrets in two places\n\nConflicts with: ADR-0001\nFix: pick one.\nStatus: open\n\n### SEVERE: vague\n\nText.\n\n### MINOR: no fix\n\nConflicts with: ADR-0002\nStatus: open\n' >> "$d/docs/design/orders-hld.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "Approved with 1 open BLOCKER"
assert_contains "$T_OUT" "finding 'SEVERE: vague' is not graded BLOCKER, MAJOR, MINOR or NIT"
assert_contains "$T_OUT" "finding 'MINOR: no fix' has no 'Fix:'"
t_end

t_begin "Approved with no review line, an undrawn diagram and an open conflict fail"
d="$(tmpdir)/approved"; fixture "$d"
edit "$d/docs/design/orders-hld.md" "- Status: Draft" "- Status: Approved"
edit "$d/docs/design/orders-hld.md" "Reviewed by: critic, 2026-09-25" "Looked at it."
edit "$d/docs/architecture/decisions.md" "**Settled by:** Architect" "**Settled by:** open"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "has no 'Reviewed by:' line (critic is mandatory)"
assert_contains "$T_OUT" "is not drawn (architecture-diagram)"
assert_contains "$T_OUT" "1 conflicts still open under an Approved HLD"
t_end

t_begin "an ADR missing from the index, a bad reversibility and a conflict with no Settled by fail"
d="$(tmpdir)/index"; fixture "$d"
printf '# ADR-0003: Use Redis\n' > "$d/docs/adr/0003-use-redis.md"
edit "$d/docs/architecture/decisions.md" "cheap: one worker" "easy"
edit "$d/docs/architecture/decisions.md" "**Settled by:** Architect" "Nobody yet."
assert_exit 1 run "$d"
assert_contains "$T_OUT" "docs/adr/0003-use-redis.md is not in the index"
assert_contains "$T_OUT" "ADR-0002 reversibility 'easy' is not cheap, awkward or irreversible"
assert_contains "$T_OUT" "conflict 'Whether uploads go through the API' has no 'Settled by:'"
t_end

t_begin "four tenets and a tenet with no breach fail"
d="$(tmpdir)/tenets"; fixture "$d"
python3 -c 'import sys,re;p=sys.argv[1];s=open(p).read();s=s[:s.index("## 5.")];s=s.replace("_A breach looks like:_ an MR that breaks it.","",1);open(p,"w").write(s)' "$d/docs/architecture/tenets.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "4 tenets, want 5 to 8"
assert_contains "$T_OUT" "tenet '1. Tenet 1' has no 'A breach looks like:' example"
t_end

t_begin "a repo plan with a wrong name, path, stack and subgroup fails"
d="$(tmpdir)/plan"; fixture "$d"
edit "$d/docs/architecture/repo-plan.json" '"name": "ShopApi", "git_path": "Shop/Server/ShopApi", "stack": "go-api"' '"name": "orders-api", "git_path": "Shop/Backend/orders-api", "stack": "rust-api"'
edit "$d/docs/architecture/repo-plan.json" '"git_path": "Shop/Client/ShopClient"' '"git_path": "Shop/Server/ShopClient"'
assert_exit 1 run "$d"
assert_contains "$T_OUT" "repo 'orders-api' is not <Project><Component> PascalCase"
assert_contains "$T_OUT" "orders-api stack 'rust-api' is not a kit stack id"
assert_contains "$T_OUT" "orders-api git_path 'Shop/Backend/orders-api' is not Shop/<Client|Server|Infrastructure>/orders-api"
assert_contains "$T_OUT" "ShopClient is a Client/Web stack under Server, want Client"
assert_contains "$T_OUT" "component 'Api' repository 'ShopApi' is not in docs/architecture/repo-plan.json"
t_end

t_begin "an entry with path . keeps its repository's own git_path"
d="$(tmpdir)/here"; fixture "$d"
edit "$d/docs/architecture/repo-plan.json" '"git_path": "Shop/Server/ShopApi", "stack": "go-api"' '"git_path": "someone/shop-docs", "path": ".", "stack": "go-api"'
assert_exit 0 run "$d"
assert_not_contains "$T_OUT" "ShopApi git_path"
t_end

t_begin "no HLD and missing architecture files fail"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 HLD files, nothing checked"
d="$(tmpdir)/bare"; fixture "$d"; rm "$d/docs/architecture/tenets.md" "$d/docs/architecture/repo-plan.json"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "docs/architecture/tenets.md: missing"
assert_contains "$T_OUT" "docs/architecture/repo-plan.json: missing"
t_end

t_summary
