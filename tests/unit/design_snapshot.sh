#!/usr/bin/env bash
# tests/unit/design_snapshot.sh: plugins/bearing/skills/design-critique/scripts/snapshot.mjs,
# the bridge that renders a framework gallery page and writes static HTML and
# CSS of its computed colours for pairs.py. Rendering needs a browser and the
# app's Playwright, so this proves the refusals that need neither: zero pages,
# a missing --base or --out, and a repository without playwright-core.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SNAP="$KIT/plugins/bearing/skills/design-critique/scripts/snapshot.mjs"

t_begin "zero pages and missing arguments write nothing"
d="$(tmpdir)"
assert_exit 1 bash -c "cd '$d' && node '$SNAP' --base http://localhost:3000/__design --out '$d/o'"
assert_contains "$T_OUT" "snapshot: 0 pages given, nothing written"
assert_exit 2 bash -c "cd '$d' && node '$SNAP' --out '$d/o' S-01"
assert_contains "$T_OUT" "usage: snapshot.mjs --base"
t_end

t_begin "a repository without playwright-core is named, not a stack trace"
d="$(tmpdir)"; printf '{"name":"x"}' > "$d/package.json"
assert_exit 1 bash -c "cd '$d' && node '$SNAP' --base http://localhost:3000/__design --out '$d/o' S-01"
assert_contains "$T_OUT" "playwright-core is not installed in this repository"
assert_eq "no" "$([ -d "$d/o" ] && echo yes || echo no)" "nothing written"
t_end

t_summary
