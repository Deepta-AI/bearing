#!/usr/bin/env bash
# tests/unit/push_claims.sh: every public "never pushes" claim names the
# opt-in exception (spec A8). Counts files and claims; fails on zero.
set -u
. "$(dirname "$0")/../lib/assert.sh"
files="README.md CONTRIBUTING.md bin/gen-guide.py docs/flows.json docs/WORKFLOW.md
plugins/bearing/templates/repo/AGENTS.md plugins/bearing/hooks/hooks.json
plugins/bearing/skills/merge-request/SKILL.md plugins/bearing/skills/autopilot/SKILL.md
plugins/bearing/skills/start-task/SKILL.md
plugins/bearing/templates/repo/CLAUDE.md plugins/bearing/templates/repo/CONTRIBUTING.md
plugins/bearing/templates/user/CLAUDE.md
plugins/bearing/templates/repo/.claude/settings.json docs/INSTALL.md
devguide/src/pages/Architecture.tsx devguide/src/pages/Autopilot.tsx devguide/src/pages/Start.tsx
devguide/src/pages/Home.tsx site/src/pages/Guides.tsx"
t_begin "every never-pushes claim is qualified"
out="$(cd "$KIT" && python3 - $files <<'PY'
import re, sys
claim = re.compile(r"never push(es|ed)?\b|engineer pushes|agent never pushes|\byou push\b|\bI push\b", re.I)
ok = re.compile(r"BEARING_AUTO_PUSH|\bopt(s|ed)?\b|brg-push", re.I)
n = k = bad = 0
for f in sys.argv[1:]:
    try:
        lines = open(f, encoding="utf-8").read().split("\n")
    except OSError as e:
        print(f"missing: {f} ({e.strerror})")
        print(f"push-claims: {n} files, {k} claims, a listed file is missing"); sys.exit(1)
    n += 1
    for i, l in enumerate(lines):
        if claim.search(l):
            k += 1
            if not ok.search(l + " " + (lines[i + 1] if i + 1 < len(lines) else "")):
                bad += 1; print(f"unqualified: {f}:{i + 1}")
if n == 0 or k == 0:
    print(f"push-claims: {n} files, {k} claims, nothing checked"); sys.exit(1)
print(f"push-claims: {n} files, {k} claims, {bad} unqualified"); sys.exit(1 if bad else 0)
PY
)"
echo "$out"
assert_contains "$out" " 0 unqualified"
t_end
t_summary
