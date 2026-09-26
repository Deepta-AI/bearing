#!/usr/bin/env bash
# tests/unit/prose_lint_check.sh: plugins/bearing/skills/prose-lint/scripts/prose_check.py
# passes clean prose and reports file:line and the class for an em dash,
# filler, praise, an attribution trailer and a hedged claim; leaves a
# table-cell dash; honours .prose-lint-ignore; reads a git diff file list
# (skipping deleted paths); and fails on empty input. The em dash and the
# robot emoji are written as bytes so this file carries neither.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/prose-lint/scripts/prose_check.py"
DASH="$(printf '\342\200\224')"
ROBOT="$(printf '\360\237\244\226')"

t_begin "clean prose passes with its counts; a table-cell dash is left"
d="$(tmpdir)"; mkdir -p "$d/docs"
printf '# Guide\n\nRun make check. It prints the count.\n\n| a | b |\n| --- | --- |\n| x | %s |\n' "$DASH" > "$d/docs/guide.md"
assert_exit 0 python3 "$CHK" "$d/docs"
assert_contains "$T_OUT" "prose-lint: 1 files, 7 lines, 0 hits in 0 files (em dash 0, filler 0, praise 0, trailer 0, hedge 0), 1 left (table filler), 0 listed files gone"
t_end

t_begin "each class is reported with file and line"
d="$(tmpdir)"
{ printf 'The cache is fast %s it skips the disk.\n' "$DASH"
  printf 'We leverage a robust, seamless pipeline.\n'
  printf 'As requested, I have successfully added it.\n'
  printf 'Co-Authored-By: Claude <noreply@example.com>\n'
  printf '%s Generated with a tool\n' "$ROBOT"
  printf 'This should work now.\n'
} > "$d/notes.md"
assert_exit 1 python3 "$CHK" "$d/notes.md"
assert_contains "$T_OUT" "problem: $d/notes.md:1: em dash:"
assert_contains "$T_OUT" "problem: $d/notes.md:2: filler: leverage"
assert_contains "$T_OUT" "problem: $d/notes.md:2: filler: robust"
assert_contains "$T_OUT" "problem: $d/notes.md:3: praise: As requested"
assert_contains "$T_OUT" "problem: $d/notes.md:4: trailer: Co-Authored-By: Claude"
assert_contains "$T_OUT" "problem: $d/notes.md:5: trailer: Generated with"
assert_contains "$T_OUT" "problem: $d/notes.md:6: hedge: should work"
assert_contains "$T_OUT" "10 hits in 1 files (em dash 1, filler 3, praise 2, trailer 3, hedge 1)"
t_end

t_begin ".prose-lint-ignore allows a word"
d="$(tmpdir)"; printf 'A robust design.\n' > "$d/a.md"; printf 'robust\n' > "$d/.prose-lint-ignore"
assert_exit 0 python3 "$CHK" --ignore "$d/.prose-lint-ignore" "$d/a.md"
assert_contains "$T_OUT" "0 hits"
t_end

t_begin "a git diff file list is read, deleted paths skipped, stdin accepted"
d="$(tmpdir)"; printf 'Certainly.\n' > "$d/b.md"
printf 'robust = 1\n' > "$d/code.py"
printf '%s\n%s\n%s\n' "$d/b.md" "$d/deleted.md" "$d/code.py" > "$d/list.txt"
assert_exit 1 python3 "$CHK" --files-from "$d/list.txt"
assert_contains "$T_OUT" "problem: $d/b.md:1: filler: Certainly"
assert_contains "$T_OUT" "1 listed files gone"
assert_not_contains "$T_OUT" "code.py" "a listed source file is not prose"
T_IN="$d/b.md"
assert_exit 1 python3 "$CHK" --files-from -
T_IN=''
assert_contains "$T_OUT" "prose-lint: 1 files"
t_end

t_begin "stdin text (commit messages) is linted as one file"
T_IN="$(printf 'feat: add export\n\nGenerated with a tool\n')"
assert_exit 1 python3 "$CHK" --text -
assert_contains "$T_OUT" "problem: <stdin>:3: trailer: Generated with"
T_IN="$(printf 'fix: handle empty list\n')"
assert_exit 0 python3 "$CHK" --text -
assert_contains "$T_OUT" "prose-lint: 1 files, 1 lines, 0 hits"
T_IN=''
assert_exit 1 python3 "$CHK" --text -
assert_contains "$T_OUT" "0 files read"
t_end

# An adopted repository's MR templates once quoted "as requested" to forbid it,
# so the first prose lint of any MR diff tripped on the kit's own guidance.
t_begin "the MR and PR templates the kit ships pass the prose lint"
assert_exit 0 python3 "$CHK" "$KIT/plugins/bearing/templates/repo/.github/PULL_REQUEST_TEMPLATE.md" \
  "$KIT/plugins/bearing/templates/repo/.gitlab/merge_request_templates/Default.md" "$KIT/plugins/bearing/skills/merge-request/templates/mr.md"
assert_contains "$T_OUT" "prose-lint: 3 files,"
assert_contains "$T_OUT" " 0 hits in 0 files"
t_end

t_begin "empty input fails: no paths, an empty list, a missing list"
d="$(tmpdir)"; : > "$d/empty.txt"
assert_exit 1 python3 "$CHK"
assert_contains "$T_OUT" "0 files read"
assert_exit 1 python3 "$CHK" --files-from "$d/empty.txt"
assert_contains "$T_OUT" "nothing checked"
assert_exit 1 python3 "$CHK" --files-from "$d/nope.txt"
assert_contains "$T_OUT" "no file list at"
mkdir -p "$d/src"; printf 'x = 1\n' > "$d/src/a.py"
assert_exit 1 python3 "$CHK" "$d/src"
assert_contains "$T_OUT" "0 files read"
t_end

t_summary
