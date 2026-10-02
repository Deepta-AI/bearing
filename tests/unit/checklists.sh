#!/usr/bin/env bash
# tests/unit/checklists.sh: plugins/bearing/bin/brg-checklists names the universal
# checklist first and one per detected stack, from repository markers, a
# diff range or files, with package.json deciding the JavaScript lane; every
# path it prints exists; it fails on zero files; and brg-guard session lists
# the checklists so any review in the session sees them.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CL="$KIT/plugins/bearing/bin/brg-checklists"

t_begin "files map to lanes, universal first, every path exists"
d="$(tmpdir)"; mkdir -p "$d/web" "$d/mobile" "$d/api"
printf '{"dependencies":{"next":"15"}}' > "$d/web/package.json"
printf '{"dependencies":{"expo":"54","react-native":"0.81"}}' > "$d/mobile/package.json"
printf '{"dependencies":{"fastify":"5"}}' > "$d/api/package.json"
assert_exit 0 bash -c "cd '$d' && '$CL' --files web/app/page.tsx mobile/app/index.tsx api/src/server.ts db/migrations/001.sql infra/main.tf lib/main.dart svc/main.go"
first="$(printf '%s\n' "$T_OUT" | head -1)"
assert_contains "$first" "plugins/bearing/skills/branch-review/references/universal-checklist.md"
for s in nextjs react-native node database infra flutter go; do assert_contains "$T_OUT" "skills/$s/references/review-checklist.md"; done
assert_contains "$T_OUT" "brg-checklists: 8 checklists from 7 files"
for p in $(printf '%s\n' "$T_OUT" | grep '^/'); do assert_file "$p"; done
t_end

t_begin "CI workflows, Dockerfiles and compose files take the infra checklist"
d="$(tmpdir)"
assert_exit 0 bash -c "cd '$d' && '$CL' --files .github/workflows/ci.yml Dockerfile docker-compose.yml .gitlab-ci.yml"
assert_contains "$T_OUT" "infra/references/review-checklist.md"
assert_contains "$T_OUT" "brg-checklists: 2 checklists from 4 files"
t_end

t_begin "python is data when the repository has dbt or dags"
d="$(tmpdir)"; : > "$d/dbt_project.yml"
assert_exit 0 bash -c "cd '$d' && '$CL' --files models/x.py"
assert_contains "$T_OUT" "data-pipeline/references/review-checklist.md"
assert_not_contains "$T_OUT" "python/"
t_end

t_begin "repository markers and a diff range"
d="$(tmpdir)"; git -C "$d" init -q -b main
printf 'module x\n' > "$d/go.mod"; printf '{"dependencies":{"react":"19"}}' > "$d/package.json"
git -C "$d" add -A; git -C "$d" -c user.email=t@example.com -c user.name=t commit -q -m init
assert_exit 0 "$CL" --repo "$d"
assert_contains "$T_OUT" "go/"; assert_contains "$T_OUT" "react/"
printf 'x = 1\n' > "$d/a.py"; git -C "$d" add -A; git -C "$d" -c user.email=t@example.com -c user.name=t commit -q -m py
assert_exit 0 bash -c "cd '$d' && '$CL' --range HEAD~1..HEAD"
assert_contains "$T_OUT" "python/"; assert_not_contains "$T_OUT" "go/"
assert_contains "$T_OUT" "from 1 files"
t_end

t_begin "zero files fail; the session lists the checklists"
d="$(tmpdir)"
assert_exit 1 bash -c "cd '$d' && '$CL' --files"
assert_contains "$T_OUT" "0 files examined, nothing checked"
git -C "$d" init -q -b main; printf 'module x\n' > "$d/go.mod"
assert_exit 0 bash -c "cd '$d' && bash '$GUARD' session"
assert_contains "$T_OUT" "Review checklists for this repository"
assert_contains "$T_OUT" "go/references/review-checklist.md"
t_end

t_summary
