#!/usr/bin/env bash
# tests/unit/learn_propose.sh: propose writes a body, prints the gh command,
# fails on zero entries, a missing jq and anything that looks identifying.
set -u
. "$(dirname "$0")/../lib/assert.sh"
L="$KIT/plugins/bearing/bin/brg-learn"
cfg="$(tmpdir)"; mkdir -p "$cfg/bearing"; f="$cfg/bearing/learnings.jsonl"; o="$(tmpdir)/p.md"
run() { XDG_CONFIG_HOME="$cfg" bash "$L" "$@"; }
t_begin "zero eligible"
: > "$f"
assert_exit 1 run propose --out "$o"
assert_contains "$T_OUT" "0 learnings seen 3 or more times"
printf '%s\n' '{"ts":"t","kind":"manual","skill":"go","key":"k","insight":"seen twice","count":2}' > "$f"
assert_exit 1 run propose --out "$o"
assert_contains "$T_OUT" "0 learnings seen 3 or more times"
rm -f "$f"
assert_exit 1 run propose --out "$o"
assert_contains "$T_OUT" "0 learnings seen 3 or more times"
t_end
t_begin "clean proposal"
printf '%s\n' '{"ts":"t","kind":"gate-block","skill":"go","key":"vet","insight":"vet fails in *.go","count":4}' > "$f"
assert_exit 0 run propose --out "$o"
assert_contains "$T_OUT" "1 learnings, written to $o"
assert_contains "$T_OUT" "gh issue create --repo Deepta-AI/bearing"
assert_contains "$(cat "$o")" "vet fails in *.go"
assert_contains "$(cat "$o")" "## go"
t_end
t_begin "clean proposal with several extension tokens, a corrupt line and a low count"
{
  printf '%s\n' 'not json at all'
  printf '%s\n' '{"ts":"t","kind":"gate-block","skill":"react","key":"a","insight":"lint fails in *.tsx and *.ts and *.css, also *.go","count":5}'
  printf '%s\n' '{"ts":"t","kind":"rerun","skill":"react","key":"b","insight":"rerun after editing *.json","count":3}'
  printf '%s\n' '{"ts":"t","kind":"manual","skill":"go","key":"c","insight":"never shown","count":1}'
} > "$f"
assert_exit 0 run propose --out "$o"
assert_contains "$T_OUT" "2 learnings, written to"
assert_contains "$(cat "$o")" "*.tsx and *.ts and *.css, also *.go"
assert_not_contains "$(cat "$o")" "never shown"
t_end
for bad in "see src/app/main.go" "see C:\\\\Users\\\\x" "mail a@b.example" "host api.client.example.com" \
  "token AbCdEfGhIjKlMnOpQrStUv" "ticket ABC-1234 broke" "server 10.0.12.7 down" "call https://x.example/y" "call ftp://host" "see /etc" "see ~/secret" "dir src/ broke" "see \\\\foo" "http:/x"; do
  t_begin "redaction: $bad"
  printf '{"ts":"t","kind":"manual","skill":"go","key":"k","insight":"%s","count":3}\n' "$bad" > "$f"
  rm -f "$o"
  assert_exit 1 run propose --out "$o"
  assert_contains "$T_OUT" "redaction failed: 1 suspect token(s)"
  e=0; [ -e "$o" ] && e=1; assert_eq 0 "$e" "no file written"
  t_end
done
t_begin "multi-dot extension tokens are not hostnames"
printf '%s\n' '{"ts":"t","kind":"gate-block","skill":"react","key":"a","insight":"types fail in *.d.ts, archive *.tar.gz, also *.go","count":3}' > "$f"
assert_exit 0 run propose --out "$o"
assert_contains "$(cat "$o")" "*.d.ts, archive *.tar.gz"
t_end
t_begin "a suspect skill name fails too"
printf '%s\n' '{"ts":"t","kind":"manual","skill":"acme/portal","key":"k","insight":"fine","count":3}' > "$f"
assert_exit 1 run propose --out "$o"
assert_contains "$T_OUT" "redaction failed"
t_end
t_begin "missing jq fails loudly"
bp="$(minimal_path bash dirname cat)"
printf '%s\n' '{"ts":"t","kind":"manual","skill":"go","key":"k","insight":"fine","count":3}' > "$f"
T_OUT="$(XDG_CONFIG_HOME="$cfg" PATH="$bp" bash "$L" propose --out "$o" 2>&1)"; T_RC=$?
assert_eq 1 "$T_RC" "exit"
assert_contains "$T_OUT" "needs jq"
t_end
t_summary
