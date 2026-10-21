#!/usr/bin/env bash
# tests/unit/changed_files.sh: brg-changed lists changed files rename-safe and
# space-safe; stop-gate prefers make check-changed and falls back to make check.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHANGED="$KIT/plugins/bearing/bin/brg-changed"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
printf '.bearing/state/\n' > "$repo/.gitignore"
printf 'a\n' > "$repo/old name.txt"; printf 'b\n' > "$repo/keep.txt"
git -C "$repo" add -A; git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m init

t_begin "renamed, spaced, untracked and modified files"
git -C "$repo" mv "old name.txt" "new name.txt"
printf 'c\n' > "$repo/fresh.txt"; printf 'b2\n' > "$repo/keep.txt"
assert_exit 0 bash "$CHANGED" --root "$repo"
assert_contains "$T_OUT" "new name.txt"
assert_not_contains "$T_OUT" "old name.txt"
assert_contains "$T_OUT" "fresh.txt"
assert_contains "$T_OUT" "keep.txt"
t_end

t_begin "since a fresh marker nothing is listed"
mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
assert_exit 0 bash "$CHANGED" --root "$repo" --since "$repo/.bearing/state/.check-passed"
assert_eq "" "$T_OUT"
t_end

# --layers: each case builds its own repository (main with one commit, then a
# branch feat) so the cases cannot leak into each other.
G() { git -C "$R" -c user.email=t@example.com -c user.name=t "$@"; }
L() { bash "$CHANGED" --layers --root "$R" "$@"; }
mkr() {
  R="$(tmpdir)"
  git -C "$R" init -q -b main
  printf 'seed\n' > "$R/seed.txt"
  G add -A; G commit -q -m init
  G checkout -q -b feat
}
put() { mkdir -p "$R/$(dirname "$1")"; printf 'x\n' > "$R/$1"; }
commit_all() { G add -A; G commit -q -m "$1"; }

t_begin "layers: each rule maps a file to its layers"
mkr
for f in src/money.ts internal/http/orders.go src/components/Button.tsx \
  e2e/visual/home.spec.ts e2e/login.spec.ts tests/integration/test_orders.py \
  docs/notes.md "src/my file.go"; do put "$f"; done
commit_all feat
assert_exit 0 L --base main
assert_contains "$T_OUT" "unit	src/money.ts"
assert_contains "$T_OUT" "api	internal/http/orders.go"
assert_contains "$T_OUT" "unit	internal/http/orders.go"
assert_contains "$T_OUT" "visual	src/components/Button.tsx"
assert_contains "$T_OUT" "ui	src/components/Button.tsx"
assert_contains "$T_OUT" "visual	e2e/visual/home.spec.ts"
assert_contains "$T_OUT" "ui	e2e/login.spec.ts"
assert_contains "$T_OUT" "api	tests/integration/test_orders.py"
assert_contains "$T_OUT" "none	docs/notes.md"
assert_contains "$T_OUT" "unit	src/my file.go"
assert_contains "$T_OUT" "brg-changed: 8 files, layers: unit api ui visual"
t_end

t_begin "layers: a toolchain file selects every layer and says so"
mkr; put package.json; commit_all tool
assert_exit 0 L --base main
assert_contains "$T_OUT" "brg-changed: 1 files, layers: unit api ui visual (toolchain changed: package.json)"
assert_contains "$T_OUT" "visual	package.json"
t_end

t_begin "layers: docs only prints none"
mkr; put README.md; commit_all docs
assert_exit 0 L --base main
assert_contains "$T_OUT" "none	README.md"
assert_contains "$T_OUT" "brg-changed: 1 files, layers: none"
t_end

t_begin "layers: zero files fails and says against what"
mkr
assert_exit 1 L --base main
assert_contains "$T_OUT" "brg-changed: 0 files changed against main"
assert_exit 1 L
assert_contains "$T_OUT" "brg-changed: 0 files changed against the working tree"
t_end

t_begin "layers: working tree without --base lists uncommitted files"
mkr; put src/a.go
assert_exit 0 L
assert_contains "$T_OUT" "unit	src/a.go"
assert_contains "$T_OUT" "brg-changed: 1 files, layers: unit"
t_end

t_begin "layers: an unknown base fails with one line"
mkr; put src/a.go; commit_all a
assert_exit 1 L --base nosuch
assert_contains "$T_OUT" "nosuch"
assert_not_contains "$T_OUT" "unit"
t_end

t_begin "layers: base diff excludes commits that landed on the base after the branch point"
mkr; put src/mine.go; commit_all mine
G checkout -q main; put x.go; commit_all onmain; G checkout -q feat
assert_exit 0 L --base main
assert_contains "$T_OUT" "src/mine.go"
assert_not_contains "$T_OUT" "x.go"
assert_contains "$T_OUT" "brg-changed: 1 files"
t_end

t_begin "layers: a branch that only deletes files still counts them"
R="$(tmpdir)"; git -C "$R" init -q -b main
put src/gone.go; put src/ui/Old.tsx; G add -A; G commit -q -m init; G checkout -q -b feat
G rm -q src/gone.go; G rm -q src/ui/Old.tsx; commit_all del
assert_exit 0 L --base main
assert_contains "$T_OUT" "unit	src/gone.go"
assert_contains "$T_OUT" "visual	src/ui/Old.tsx"
assert_contains "$T_OUT" "brg-changed: 2 files, layers: unit ui visual"
t_end

t_begin "layers: a shallow clone with no merge base fails and says so"
src="$(tmpdir)"; git -C "$src" init -q -b main
printf 'a\n' > "$src/a.txt"; git -C "$src" add -A; git -C "$src" -c user.email=t@example.com -c user.name=t commit -q -m one
printf 'b\n' > "$src/b.go"; git -C "$src" add -A; git -C "$src" -c user.email=t@example.com -c user.name=t commit -q -m two
git -C "$src" checkout -q -b old HEAD~1
printf 'c\n' > "$src/c.go"; git -C "$src" add -A; git -C "$src" -c user.email=t@example.com -c user.name=t commit -q -m three
R="$(tmpdir)"; rmdir "$R" 2>/dev/null; R="$R/clone"
git clone -q --depth 1 --no-single-branch "file://$src" "$R" 2>/dev/null
git -C "$R" checkout -q old
git -C "$R" fetch -q --depth 1 origin main 2>/dev/null
git -C "$R" branch -q -f basetip FETCH_HEAD 2>/dev/null
assert_exit 1 L --base basetip
assert_contains "$T_OUT" "no merge base"
assert_contains "$T_OUT" "basetip"
t_end

t_begin "layers: outside a repository fails with one stderr line"
nr="$(tmpdir)"
assert_exit 1 sh -c 'cd "$1" && bash "$2" --layers' _ "$nr" "$CHANGED"
assert_contains "$T_OUT" "brg-changed: not a git repository"
so="$(cd "$nr" && bash "$CHANGED" --layers 2>/dev/null)"
assert_eq "" "$so"
t_end

t_begin "layers: every error line goes to stderr, not stdout"
mkr; put src/a.go; commit_all a
so="$(L --base nosuch 2>/dev/null)"; assert_eq "" "$so"
se="$(L --base nosuch 2>&1 >/dev/null)"; assert_contains "$se" "base nosuch does not resolve"
mkr
so="$(L --base main 2>/dev/null)"; assert_eq "" "$so"
se="$(L --base main 2>&1 >/dev/null)"; assert_contains "$se" "0 files changed against main"
t_end

t_begin "default mode is unchanged by the new flags"
mkr; put src/a.go
assert_exit 0 bash "$CHANGED" --root "$R"
assert_not_contains "$T_OUT" "brg-changed:"
assert_contains "$T_OUT" "src/a.go"
t_end

sid=s1
in_repo() { ( cd "$repo" && bash "$GUARD" "$@" ) }
t_begin "stop-gate asks for check-changed when the target exists"
touch -t 202001010000 "$repo/.bearing/state/.check-passed"
: > "$repo/.bearing/state/.session-$sid"; touch -t 202001010000 "$repo/.bearing/state/.session-$sid"
printf 'check:\n\t@touch .bearing/state/.check-passed\ncheck-changed:\n\t@true\n' > "$repo/Makefile"
printf 'd\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check-changed"
t_end

t_begin "a check-changed pass satisfies the gate"
sleep 1; touch "$repo/.bearing/state/.check-changed-passed"
assert_exit 0 in_repo stop-gate --id "$sid"
t_end

t_begin "without check-changed the old message stands"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
rm -f "$repo/.bearing/state/.check-changed-passed"; sleep 1; printf 'e\n' > "$repo/fresh.txt"
assert_exit 2 in_repo stop-gate --id "$sid"
assert_contains "$T_OUT" "Run make check and fix what fails"
t_end

# The Stop gate, like brg-push's gate, does not hold a session to this
# task's uncommitted progress file or to .scratch/: merge-request writes the
# progress file after make check by design, and neither is ever pushed.
r2="$(tmpdir)"
git -C "$r2" init -q -b main
git -C "$r2" config user.email t@example.com; git -C "$r2" config user.name t
printf '.bearing/state/\n' > "$r2/.gitignore"
printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$r2/Makefile"
mkdir -p "$r2/docs/progress" "$r2/.scratch"
printf 'p\n' > "$r2/docs/progress/ABC-1.md"; printf 's\n' > "$r2/.scratch/kept.md"
git -C "$r2" add -A; git -C "$r2" commit -q -m init
git -C "$r2" switch -q -c feature/ABC-1-Thing
mkdir -p "$r2/.bearing/state"
touch -t 202001010000 "$r2/.bearing/state/.session-$sid"
sleep 1; touch "$r2/.bearing/state/.check-passed"; sleep 1
in_r2() { ( cd "$r2" && bash "$GUARD" "$@" ) }

t_begin "stop-gate ignores an untracked progress file of the current task"
git -C "$r2" switch -q -c feature/ABC-3-Other
printf 'q\n' > "$r2/docs/progress/ABC-3.md"
assert_exit 0 in_r2 stop-gate --id "$sid"
rm -f "$r2/docs/progress/ABC-3.md"; git -C "$r2" switch -q feature/ABC-1-Thing
t_end

t_begin "stop-gate ignores this task's uncommitted progress file and .scratch/"
printf 'p2\n' >> "$r2/docs/progress/ABC-1.md"; printf 's2\n' >> "$r2/.scratch/kept.md"; printf 'n\n' > "$r2/.scratch/new.md"
assert_exit 0 in_r2 stop-gate --id "$sid"
assert_exit 0 bash "$CHANGED" --root "$r2" --skip-notes
assert_eq "" "$T_OUT" "brg-changed --skip-notes lists none of them"
assert_exit 0 bash "$CHANGED" --root "$r2"
assert_contains "$T_OUT" "docs/progress/ABC-1.md" "without --skip-notes the progress file is listed"
t_end

t_begin "another task's progress file, a staged progress change and a near name still count"
printf 'o\n' > "$r2/docs/progress/ABC-9.md"
assert_exit 2 in_r2 stop-gate --id "$sid"
assert_contains "$T_OUT" "1 file(s) changed"
rm -f "$r2/docs/progress/ABC-9.md"
printf 'b\n' > "$r2/docs/progress/ABC-1.md.bak"
assert_exit 2 in_r2 stop-gate --id "$sid"
rm -f "$r2/docs/progress/ABC-1.md.bak"
git -C "$r2" add docs/progress/ABC-1.md
assert_exit 2 in_r2 stop-gate --id "$sid"
assert_contains "$T_OUT" "1 file(s) changed"
printf 'p3\n' >> "$r2/docs/progress/ABC-1.md"
assert_exit 2 in_r2 stop-gate --id "$sid"
assert_contains "$T_OUT" "1 file(s) changed" "staged then changed again (MM) still counts"
t_end

t_begin "a progress change committed after the check passes the Stop gate and still counts for brg-push"
git -C "$r2" add docs/progress/ABC-1.md; git -C "$r2" commit -q -m "docs: progress [ABC-1]"
assert_exit 0 in_r2 stop-gate --id "$sid"
fns="$(tmpdir)/fns.sh"; sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$fns"
assert_exit 0 bash -c '. "$1"; root="$2"; skipped="$nl$4$nl"; printf "%s\0" "$4" | gate_count "$3"' _ "$fns" "$r2" "$r2/.bearing/state/.check-passed" docs/progress/ABC-1.md
assert_eq "1 1" "$T_OUT" "brg-push's gate counts the committed progress change"
t_end

t_summary
