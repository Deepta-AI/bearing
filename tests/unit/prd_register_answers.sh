#!/usr/bin/env bash
# tests/unit/prd_register_answers.sh: plugins/bearing/skills/prd/scripts/register_answers.py
# rank puts open assumptions first, then by impact (Affects ranges counted
# in full), and splits readings into options with the assumed one marked;
# apply confirms a reading or "keep" with date and source and keeps the
# old decision, leaves "other" and "ask-client" open with a dated note,
# rewrites the Needs-your-confirmation list and the counts, moves
# confirmed rows below the open assumptions, and fails on an empty
# register, an empty answers file, an unknown id or an unknown choice.
set -u
. "$(dirname "$0")/../lib/assert.sh"
RA="$KIT/plugins/bearing/skills/prd/scripts/register_answers.py"
d="$(tmpdir)"

register() {
  cat > "$1" <<'MD'
# Open questions: Clinic portal

PRD: docs/product/PRD.md   Updated: 2026-10-01
Entries: 4   Open: 4   Needs your confirmation: 3

## Needs your confirmation

- Q-001 Which lab formats? Assumed: PDF only. (REQ-001)
- Q-002 Who owns the data? Assumed: the clinic. (REQ-001 to REQ-020)
- Q-004 Which region hosts it? Assumed: Mumbai. (REQ-003)

## Register

| Q | Status | Kind | Where | Basis | Question | Readings | Decision | Why | Affects |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q-001 | open | gap | REQ-001 | assumption | Which lab formats are accepted? | (a) PDF only; (b) PDF and images; (c) any attachment | (a) PDF only | samples are PDF | REQ-001 |
| Q-002 | open | gap | REQ-002 | assumption | Who owns the data? | (a) the clinic; (b) the lab. Experiment: ask the clinic lead | (a) | contracts | REQ-001 to REQ-020 |
| Q-004 | open | gap | REQ-003 | assumption | Which region hosts it? | (a) Mumbai; (b) Hyderabad | (a) | latency | REQ-003 |
| Q-003 | open | open-question | REQ-004 | convention | What does fast mean? | (a) LCP 2.5 s; (b) full load 3 s | (a) | lab check | REQ-004, REQ-005 |
MD
}

t_begin "rank: open assumptions first by impact, readings split, experiment kept apart"
register "$d/q.md"
assert_exit 0 python3 "$RA" rank --questions "$d/q.md" --json
assert_eq "Q-002 Q-001 Q-004 Q-003" "$(printf '%s' "$T_OUT" | python3 -c 'import json,sys; t=sys.stdin.read(); print(" ".join(e["id"] for e in json.loads(t[t.index("["):t.rindex("]")+1])))')"
assert_contains "$T_OUT" '"affects": 20'
assert_contains "$T_OUT" '"experiment": "ask the clinic lead"'
assert_contains "$T_OUT" "rank: 4 open entries ranked, 3 assumptions first"
t_end

t_begin "apply: a reading, keep, other and ask-client"
register "$d/q.md"
cat > "$d/a.json" <<'JSON'
{"Q-001": {"choice": "b", "note": "scans arrive as JPG"},
 "Q-002": {"choice": "keep"},
 "Q-004": {"choice": "ask-client", "note": "the clinic IT lead"},
 "Q-003": {"choice": "other", "note": "under 2 s on 4G"}}
JSON
assert_exit 0 python3 "$RA" apply --questions "$d/q.md" --answers "$d/a.json" --date 2026-10-02 --source "Ravi in session"
assert_contains "$T_OUT" "confirmed 2 (Q-001, Q-002); needs review 1 (Q-003); asked the client 1"
q="$(cat "$d/q.md")"
assert_contains "$q" "| Q-001 | confirmed |"
assert_contains "$q" "confirmed 2026-10-02 by Ravi in session: (b) PDF and images; was: (a) PDF only; note: scans arrive as JPG"
assert_contains "$q" "confirmed 2026-10-02 by Ravi in session as assumed: (a)"
assert_contains "$q" "| Q-003 | open |"
assert_contains "$q" "needs review: under 2 s on 4G"
assert_contains "$q" "asked the clinic IT lead on 2026-10-02"
assert_contains "$q" "Entries: 4   Open: 2   Needs your confirmation: 1"
assert_eq "- Q-004 Which region hosts it? Assumed: Mumbai. (REQ-003)" "$(grep '^- Q-' "$d/q.md")"
assert_eq "Q-004 Q-001 Q-002 Q-003" "$(grep -oE '^\| Q-[0-9]+' "$d/q.md" | tr -d '| ' | paste -sd' ')"
t_end

t_begin "apply: decide confirms the session's judged decision for an open answer"
register "$d/q.md"
printf '{"Q-003": {"choice": "other", "note": "under 2 s on 4G"}}' > "$d/o.json"
assert_exit 0 python3 "$RA" apply --questions "$d/q.md" --answers "$d/o.json" --date 2026-10-02
printf '{"Q-003": {"choice": "decide", "decision": "LCP under 2 s on 4G"}}' > "$d/dec.json"
assert_exit 0 python3 "$RA" apply --questions "$d/q.md" --answers "$d/dec.json" --date 2026-10-02 --source "Ravi in session"
assert_contains "$(cat "$d/q.md")" "| Q-003 | confirmed |"
assert_contains "$(cat "$d/q.md")" "confirmed 2026-10-02 by Ravi in session: LCP under 2 s on 4G; was: (a); answered"
printf '{"Q-003": {"choice": "decide"}}' > "$d/dec0.json"
assert_exit 1 python3 "$RA" apply --questions "$d/q.md" --answers "$d/dec0.json"
t_end

t_begin "fails closed: empty answers, unknown id, unknown choice, other without a note, empty register"
register "$d/q.md"
printf '{}' > "$d/empty.json"
assert_exit 1 python3 "$RA" apply --questions "$d/q.md" --answers "$d/empty.json"
assert_contains "$T_OUT" "0 answers"
printf '{"Q-099": {"choice": "a"}}' > "$d/unknown.json"
assert_exit 1 python3 "$RA" apply --questions "$d/q.md" --answers "$d/unknown.json"
assert_contains "$T_OUT" "not in the register: Q-099"
printf '{"Q-001": {"choice": "z"}}' > "$d/badchoice.json"
assert_exit 1 python3 "$RA" apply --questions "$d/q.md" --answers "$d/badchoice.json"
printf '{"Q-001": {"choice": "other"}}' > "$d/nonote.json"
assert_exit 1 python3 "$RA" apply --questions "$d/q.md" --answers "$d/nonote.json"
assert_contains "$T_OUT" "needs a note"
printf '# Open questions\n' > "$d/none.md"
assert_exit 1 python3 "$RA" rank --questions "$d/none.md"
assert_contains "$T_OUT" "0 register rows"
t_end

t_summary
