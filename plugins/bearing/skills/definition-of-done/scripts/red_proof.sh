#!/usr/bin/env bash
# red_proof.sh: prove a regression test fails without the fix, without
# touching the working tree.
#
#   red_proof.sh <base> '<test command>'
#   red_proof.sh --commit <sha> '<test command>'
#
# --commit proves one fix commit of a long branch: the base is that commit's
# parent and only the files that commit changed are considered, so a branch
# of many fixes is proved one fix at a time.
#
# In a throwaway worktree of HEAD under .scratch/: link the dependency
# folders (node_modules, .venv, vendor), run the test command and require
# it to pass (the control: the environment works and the test is green with
# the fix); then put every changed file that is not a test back to <base>
# (files the branch added are removed) and run it again, requiring it to
# fail. Toolchain files (package manifests, lockfiles, build and test
# configs, the Makefile) stay at HEAD: reverting them breaks the runner, and
# a runner that cannot start is not a red. The only difference between the
# two runs is the fix, so a red second
# run is the proof, provided the test ran and its assertion failed: a red run
# that stops at an import, collection or build error (the test names a symbol
# the fix added) proves only that the symbol is new. The worktree is removed
# on exit.
#
# Prints "red-proof: ..." with the counts and the tail of each run. Exits 0
# when green then red on an assertion; 1 when the test passes without the
# fix, fails with it, is red only because it cannot load or build without the
# fix, or when there are zero test files or zero non-test files in the diff
# (nothing to prove); 2 on a usage error. bash 3.2 safe.
set -u
commit=""
if [ "${1:-}" = "--commit" ]; then commit="${2:-}"; base="${commit:+$commit^}"; cmd="${3:-}"
else base="${1:-}"; cmd="${2:-}"; fi
[ -n "$base" ] && [ -n "$cmd" ] || { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "red-proof: not a git repository" >&2; exit 2; }
cd "$root" || exit 2
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "red-proof: unknown base $base" >&2; exit 2; }

# is_toolchain: files the runner itself needs; kept at HEAD in the red run.
is_toolchain() {
  case "${1##*/}" in
    package.json|pnpm-lock.yaml|pnpm-workspace.yaml|package-lock.json|yarn.lock|bun.lockb|tsconfig*.json|*.config.ts|*.config.js|*.config.mjs|*.config.cjs|Makefile|go.mod|go.sum|pyproject.toml|uv.lock|poetry.lock|requirements*.txt|setup.cfg|tox.ini|pytest.ini|Cargo.toml|Cargo.lock|build.gradle|build.gradle.kts|settings.gradle|settings.gradle.kts|gradle.properties|Package.swift|Package.resolved|pubspec.yaml|pubspec.lock|.nvmrc|.node-version|.python-version) return 0 ;;
  esac
  return 1
}

is_test() {
  case "$1" in
    *_test.go|*.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.ts|*.spec.tsx|*.spec.js|*_test.py|*/test_*.py|test_*.py|*Test.kt|*Tests.kt|*Test.java|*Tests.swift|*_test.dart) return 0 ;;
    tests/*|*/tests/*|test/*|*/test/*|e2e/*|*/e2e/*|__tests__/*|*/__tests__/*|*/androidTest/*|*/UITests/*|.maestro/*|*/testdata/*|testdata/*) return 0 ;;
  esac
  return 1
}

if [ -n "$commit" ]; then changed="$(git diff --name-only "$commit^" "$commit")"; else changed="$(git diff --name-only "$base"...HEAD)"; fi
tests=""; prod=""; nt=0; np=0; nk=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if is_test "$f"; then tests="$tests$f
"; nt=$((nt+1))
  elif is_toolchain "$f"; then nk=$((nk+1))
  else prod="$prod$f
"; np=$((np+1)); fi
done <<EOF
$changed
EOF
[ "$nt" -gt 0 ] || { echo "red-proof: 0 test files changed since $base, nothing to prove" >&2; exit 1; }
[ "$np" -gt 0 ] || { echo "red-proof: 0 non-test files changed since $base, nothing to revert, nothing to prove" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || echo "red-proof: note: uncommitted changes are not in the proof; it runs on the HEAD commit"

mkdir -p .scratch
dir=".scratch/dod-red-$$"
cleanup() { git worktree remove --force "$dir" >/dev/null 2>&1 || rm -rf "$dir"; git worktree prune >/dev/null 2>&1; }
trap cleanup EXIT
git worktree add -q --detach "$dir" HEAD || { echo "red-proof: could not create the worktree" >&2; exit 1; }
for dep in node_modules .venv vendor; do
  [ -e "$dep" ] && [ ! -e "$dir/$dep" ] && ln -s "$root/$dep" "$dir/$dep"
done

# Bytecode caches key on mtime and size: a one-character fix written in the
# same second reuses the stale cache and the revert never runs. No caches.
export PYTHONDONTWRITEBYTECODE=1
run() { ( cd "$dir" && bash -c "$cmd" ) >"$dir.out" 2>&1; }

run; green=$?
echo "red-proof: with the fix (HEAD): exit $green"
tail -8 "$dir.out" | sed 's/^/  | /'
if [ "$green" -ne 0 ]; then
  rm -f "$dir.out"
  echo "red-proof: the test fails with the fix in a clean worktree; fix the environment or the test first, nothing proven"
  exit 1
fi

find "$dir" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null
reverted=0; removed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if git cat-file -e "$base:$f" 2>/dev/null; then
    mkdir -p "$(dirname "$dir/$f")" && git show "$base:$f" > "$dir/$f" && reverted=$((reverted+1))
  else
    rm -f "$dir/$f" && removed=$((removed+1))
  fi
done <<EOF
$prod
EOF

run; red=$?
kept=""; [ "$nk" -eq 0 ] || kept=", $nk toolchain file$( [ "$nk" -eq 1 ] || echo s) kept at HEAD"
echo "red-proof: without the fix ($reverted files back to $base, $removed added files removed$kept): exit $red"
tail -8 "$dir.out" | sed 's/^/  | /'
# Load and build failures: pytest, go, node test runners, gradle, swift.
why="$(grep -m1 -E 'ImportError|ModuleNotFoundError|ERROR collecting|errors? during collection|AttributeError: module|\[build failed\]|\[setup failed\]|undefined: |cannot find package|Cannot find module|Failed to resolve import|SyntaxError|Compilation error|Unresolved reference|cannot find .* in scope|Cannot find package|is not a function|is not defined|ERR_PNPM|No package found|command not found' "$dir.out")"
rm -f "$dir.out"
if [ "$red" -eq 0 ]; then
  echo "red-proof: $nt test files, $np non-test files; GREEN without the fix: the test does not prove the bug"
  exit 1
fi
if [ -n "$why" ]; then
  echo "red-proof: saw: $why"
  echo "red-proof: $nt test files, $np non-test files; RED FOR THE WRONG REASON: the test cannot load or build without the fix, so its assertions never ran against the bug; nothing proven"
  exit 1
fi
echo "red-proof: $nt test files, $np non-test files; green with the fix, red without it: proven"
