#!/usr/bin/env bash
# tests/unit/docs_drift.sh: skills/docs-drift/scripts/docs_drift.py
# flags a broken link, a missing backticked path and an undefined make
# target; leaves URLs, placeholders, gitignored paths and a make that is an
# argument alone; warns on an env var no code reads and on a doc whose code
# moved on; passes a clean repository; fails under --strict on warnings, and
# fails on a repository with no docs.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/skills/docs-drift/scripts/docs_drift.py"

# fixture <dir>: a git repository with a Makefile, one source file reading
# DATABASE_URL, a README full of claims and one doc under docs/.
fixture() {
  mkdir -p "$1/src" "$1/docs"
  (cd "$1" && git init -q . && git config user.email t@example.com && git config user.name t && git config commit.gpgsign false)
  printf '.PHONY: check test\ncheck: test\n\t@echo ok\ntest:\n\t@echo ok\n' > "$1/Makefile"
  printf 'import os\nURL = os.environ["DATABASE_URL"]\n' > "$1/src/app.py"
  printf '.env\n' > "$1/.gitignore"
  cat > "$1/README.md" <<'MD'
# Demo

See the [guide](docs/guide.md) and the [missing page](docs/missing.md).
The entry point is `src/app.py`; the old one was `src/old_app.py`.
Run `make check` before a merge request, then `make deploy-all`.
Docs live at https://example.com and [the site](https://example.com/x).
Each service has `<service>/main.go` and records in `docs/adr/NNNN-title.md`.
Copy `.env.example` to `.env`; set `DATABASE_URL` and `SECRET_TOKEN_X`.
On a Mac: `brew install jq make`.
MD
  cat > "$1/docs/guide.md" <<'MD'
# Guide

```bash
make test
```

Back to the [README](../README.md).
MD
  (cd "$1" && git add -A && git commit -q -m init)
}
run() { python3 "$CHK" --root "$1" "${@:2}"; }

t_begin "broken link, missing path and unknown target fail with exact counts"
d="$(tmpdir)/drift"; fixture "$d"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "README.md:3: broken-link: (docs/missing.md) resolves to docs/missing.md, which does not exist"
assert_contains "$T_OUT" "README.md:4: broken-path: \`src/old_app.py\` does not exist"
assert_contains "$T_OUT" "README.md:5: broken-make: make deploy-all: no such target in the Makefile"
assert_contains "$T_OUT" "README.md:8: broken-path: \`.env.example\` does not exist"
assert_contains "$T_OUT" "README.md:8: env-unused: \`SECRET_TOKEN_X\` appears in no code, config or .env.example"
assert_contains "$T_OUT" "docs-drift: 2 docs checked, 11 references checked, 4 broken, 1 warnings"
t_end

t_begin "URLs, placeholders, a gitignored path and make as an argument are not flagged"
assert_not_contains "$T_OUT" "example.com"
assert_not_contains "$T_OUT" "<service>"
assert_not_contains "$T_OUT" "NNNN"
assert_not_contains "$T_OUT" "\`.env\` does not exist"
assert_not_contains "$T_OUT" "make jq"
assert_not_contains "$T_OUT" "DATABASE_URL"
assert_not_contains "$T_OUT" "make test"
t_end

t_begin "a clean repository passes; its one warning fails only under --strict"
d="$(tmpdir)/clean"; fixture "$d"
printf 'DATABASE_URL=postgres://localhost/demo\n' > "$d/.env.example"
sed -i.bak -e 's/ and the \[missing page\](docs\/missing.md)//' -e 's/; the old one was `src\/old_app.py`//' \
  -e 's/, then `make deploy-all`//' "$d/README.md" && rm -f "$d/README.md.bak"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "docs-drift: 2 docs checked, 8 references checked, 0 broken, 1 warnings"
assert_exit 1 run "$d" --strict
assert_contains "$T_OUT" "docs-drift: 2 docs checked, 8 references checked, 0 broken, 1 warnings"
printf 'TOKEN = "SECRET_TOKEN_X"\n' >> "$d/src/app.py"
assert_exit 0 run "$d" --strict
assert_contains "$T_OUT" "docs-drift: 2 docs checked, 8 references checked, 0 broken, 0 warnings"
t_end

t_begin "--json parses and carries the same counts"
d="$(tmpdir)/json"; fixture "$d"
assert_exit 1 run "$d" --json
n="$(printf '%s' "$T_OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["docs"], d["references"], d["broken"], d["warnings"], len(d["findings"]), d["findings"][0]["kind"])')"
assert_eq "2 11 4 1 5 broken-link" "$n" "json counts"
t_end

t_begin "ignore markers and --exclude silence lines and docs"
d="$(tmpdir)/ignore"; fixture "$d"
sed -i.bak 's/^Run `make check`/<!-- docs-drift: ignore -->Run `make check`/' "$d/README.md" && rm -f "$d/README.md.bak"
assert_exit 1 run "$d"
assert_not_contains "$T_OUT" "deploy-all"
assert_contains "$T_OUT" "3 broken, 1 warnings"
printf '<!-- docs-drift: ignore-file -->\n' >> "$d/docs/guide.md"
assert_exit 1 run "$d" --exclude README.md
assert_contains "$T_OUT" "docs-drift: 1 docs skipped by docs-drift: ignore-file"
assert_contains "$T_OUT" "docs-drift: 0 docs checked, 0 references checked, 0 broken, 0 warnings"
t_end

t_begin "a doc whose referenced code moved on is stale (warning)"
d="$(tmpdir)/stale"; fixture "$d"
for i in 1 2 3; do printf '# change %s\n' "$i" >> "$d/src/app.py"; (cd "$d" && git commit -q -am "change $i"); done
assert_exit 1 run "$d" --stale-after 3
assert_contains "$T_OUT" "README.md:1: stale: 3 commits touched referenced paths after the doc's last commit"
assert_contains "$T_OUT" "(src/app.py 3)"
assert_contains "$T_OUT" "4 broken, 2 warnings"
assert_exit 1 run "$d" --stale-after 4
assert_contains "$T_OUT" "4 broken, 1 warnings"
t_end

t_begin "a broken claim in an ADR is a history warning, not a failure"
d="$(tmpdir)/history"; mkdir -p "$d/docs/adr" "$d/src"
printf 'package main\n' > "$d/src/main.go"
printf '# 1. Start in Go\n\nThe entry point is `src/main.go`, which replaced `src/server.py`.\n' > "$d/docs/adr/0001-go.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "docs/adr/0001-go.md:3: history: \`src/server.py\` does not exist (a dated record: not rewritten)"
assert_contains "$T_OUT" "docs-drift: 1 docs checked, 2 references checked, 0 broken, 1 warnings"
assert_exit 1 run "$d" --strict
t_end

t_begin "a repository with no docs fails and says so"
d="$(tmpdir)/empty"; mkdir -p "$d/src"
(cd "$d" && git init -q . && printf 'x = 1\n' > src/a.py && git add -A)
assert_exit 1 run "$d"
assert_contains "$T_OUT" "docs-drift: 0 docs checked, 0 references checked, 0 broken, 0 warnings"
assert_contains "$T_OUT" "0 docs found under"
assert_contains "$T_OUT" "nothing checked"
t_end

t_begin "outside git: files are walked and staleness is skipped"
d="$(tmpdir)/nogit"; mkdir -p "$d/src"
printf 'Start at `src/main.go` and `src/gone.go`.\n' > "$d/README.md"
printf 'package main\n' > "$d/src/main.go"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "README.md:1: broken-path: \`src/gone.go\` does not exist"
assert_contains "$T_OUT" "docs-drift: 1 docs checked, 2 references checked, 1 broken, 0 warnings"
t_end

t_summary
