#!/usr/bin/env bash
# tests/unit/gen_wiki.sh: bin/gen-wiki.py writes one wiki page per exported
# doc and flow plus a sidebar, leaves no relative link a wiki would 404 on,
# links repository files on GitLab (/-/blob/) and GitHub (/blob/) by the
# host's own shape, escapes the <ID> slots a wiki would drop as HTML, and
# stamps every page with its source and commit. A folder that is not a
# clone of the wiki is refused (an export there could never be pushed).
set -u
. "$(dirname "$0")/../lib/assert.sh"
GEN="$KIT/bin/gen-wiki.py"
flows="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["flows"]))' "$KIT/docs/flows.json")"

t_begin "GitLab export: every page, wiki links, repository links, no relative links left"
out="$(tmpdir)"
assert_exit 0 python3 "$GEN" "$out" --any-dir --repo-url https://git.example/group/kit
assert_contains "$T_OUT" "$((7 + flows)) pages and a sidebar"
assert_contains "$T_OUT" "0 made plain text"
for p in home Workflow Skills Install Trackers Third-party-packs Repository-layout _sidebar Flow-Bug-fix Flow-Feature-addition; do
  assert_file "$out/$p.md"
done
n="$(ls "$out"/Flow-*.md | wc -l | tr -d ' ')"
assert_eq "$flows" "$n" "one page per flow in docs/flows.json"
rel="$(grep -hoE '\]\([^)#: ]+\.md(#[^)]*)?\)' "$out"/*.md | head -3)"
assert_eq "" "$rel" "no relative .md link left in any page"
assert_contains "$(cat "$out/home.md")" "](Workflow)"
assert_contains "$(cat "$out/home.md")" "https://git.example/group/kit/-/blob/main/"
assert_contains "$(head -1 "$out/Workflow.md")" "Generated from [docs/WORKFLOW.md](https://git.example/group/kit/-/blob/main/docs/WORKFLOW.md) at commit"
# The stamp is the last commit that changed the page's own source, so a
# commit elsewhere in the kit leaves the page unchanged.
for pair in Workflow:docs/WORKFLOW.md Flow-Bug-fix:docs/flows.json home:README.md; do
  src="${pair#*:}"
  if [ -n "$(git -C "$KIT" status --porcelain -- "$src")" ]; then want=uncommitted; else want="$(git -C "$KIT" log -1 --format=%h -- "$src")"; fi
  assert_contains "$(head -1 "$out/${pair%%:*}.md")" "at commit \`$want\`"
done
assert_not_contains "$(cat "$out"/Flow-*.md)" "<ID>"
assert_contains "$(cat "$out/Flow-Bug-fix.md")" "&lt;ID&gt;"
for f in "$out"/Flow-*.md; do assert_contains "$(cat "$out/_sidebar.md")" "($(basename "$f" .md))"; done
t_end

t_begin "GitHub export: file links have no /-/ segment"
out="$(tmpdir)"
assert_exit 0 python3 "$GEN" "$out" --any-dir --repo-url https://github.com/org/kit
assert_contains "$(cat "$out/home.md")" "https://github.com/org/kit/blob/main/"
assert_not_contains "$(cat "$out/home.md")" "github.com/org/kit/-/"
t_end

t_begin "no repository URL: repository links become plain text, never relative"
out="$(tmpdir)"
assert_exit 0 python3 "$GEN" "$out" --any-dir --repo-url ""
assert_contains "$T_OUT" "0 to the repository"
assert_eq "" "$(grep -hoE '\]\([^)#: ]+\.md(#[^)]*)?\)' "$out"/*.md | head -1)" "still no relative .md link"
t_end

t_begin "a folder that is not a clone of the wiki is refused, and nothing is written"
out="$(tmpdir)/not-a-clone"
assert_exit 1 python3 "$GEN" "$out" --repo-url https://git.example/group/kit
assert_contains "$T_OUT" "is not a clone of the wiki repository"
assert_contains "$T_OUT" "0 pages written"
assert_eq "" "$(ls "$out" 2>/dev/null)" "no pages in the folder"
t_end

t_begin "a clone (a folder with .git) is accepted without --any-dir"
out="$(tmpdir)"; git -C "$out" init -q
assert_exit 0 python3 "$GEN" "$out" --repo-url https://git.example/group/kit
assert_contains "$T_OUT" "$((7 + flows)) pages and a sidebar"
t_end

echo "gen_wiki: 5 exports, $flows flows"
t_summary
