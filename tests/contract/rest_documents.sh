#!/usr/bin/env bash
# tests/contract/rest_documents.sh: plugins/bearing/bin/brg-rest's document
# commands (docs, doc-get, doc-put) and the --document option of create and
# update, against tests/contract/fake_tracker.py with the protocol's optional document
# shapes. doc-put creates a document carrying an invisible source marker; run
# again on the same file it changes nothing; on an edited file it updates in
# place; with a new title it renames the same document, never a second copy.
# --parent nests a document. A create answered 502 after it applied leaves one
# document. A story created or updated with --document points at it. A server
# without documents is named in one line and nothing is posted. An empty file,
# an unknown type and a non-numeric id are refused before any call, and the
# token never reaches the output. The developer's env file and cached token are
# never read.
set -u
. "$(dirname "$0")/../lib/assert.sh"
RS="$KIT/plugins/bearing/bin/brg-rest"
FAKE="$KIT/tests/contract/fake_tracker.py"
work="$(tmpdir)"; cfg="$(tmpdir)"; home="$(tmpdir)"
LOG="$work/requests.log"; : > "$LOG"
python3 "$FAKE" --log "$LOG" --port-file "$work/port" >"$work/server.out" 2>&1 & PID=$!
trap 'kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; _t_cleanup' EXIT
i=0; while [ ! -s "$work/port" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done
[ -s "$work/port" ] || { echo "fake tracker did not start" >&2; exit 1; }
URL="http://127.0.0.1:$(tr -d '[:space:]' < "$work/port")"
TOKEN="sekrit-docs-7c1e"

rs() {
  env -u BEARING_TRACKER_PASSWORD -u BEARING_TRACKER_EMAIL BEARING_ENV=/nonexistent XDG_CONFIG_HOME="$cfg" HOME="$home" \
    BEARING_TRACKER_URL="$URL" BEARING_TRACKER_TOKEN="$TOKEN" BEARING_TRACKER_PROJECT=PP bash "$RS" "$@"
}
state() { curl -sS --max-time 5 "$URL/_state?tracker=rest" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(eval('d' + sys.argv[1])) if not isinstance(eval('d' + sys.argv[1]), (int, str)) else eval('d' + sys.argv[1]))" "$1"; }
ctl() { curl -sS --max-time 5 -X "$1" "$URL$2"; }
posts() { grep -c '^POST /api/projects/PP/documents' "$LOG"; }

printf '# PRD: Clinic portal\n\n## 1. Problem\n\nReports are re-keyed.\n' > "$work/PRD.md"

t_begin "doc-put creates a document with its type and an invisible source marker"
assert_exit 0 rs doc-put PP --title "PRD: Clinic portal" --file "$work/PRD.md" --type prd --source docs/product/PRD.md
assert_contains "$T_OUT" '"action":"created"'
assert_contains "$T_OUT" '"doc_type":"prd"'
assert_not_contains "$T_OUT" "$TOKEN"
DOC="$(printf '%s' "$T_OUT" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)"
assert_exit 0 rs doc-get "$DOC"
assert_contains "$T_OUT" "Reports are re-keyed."
assert_contains "$T_OUT" "<!-- bearing-doc: docs/product/PRD.md -->"
assert_exit 0 rs docs PP
assert_contains "$T_OUT" '"title":"PRD: Clinic portal"'
assert_contains "$T_OUT" "1 document(s) in PP"
assert_not_contains "$T_OUT" "Reports are re-keyed."
t_end

t_begin "run again unchanged: nothing is written; edited: updated in place; renamed: the same document"
n="$(posts)"
assert_exit 0 rs doc-put PP --title "PRD: Clinic portal" --file "$work/PRD.md" --type prd --source docs/product/PRD.md
assert_contains "$T_OUT" '"action":"unchanged"'
assert_eq "$n" "$(posts)" "no POST on an unchanged run"
assert_eq 0 "$(grep -c "^PUT /api/documents/$DOC" "$LOG")" "no PUT on an unchanged run"
printf '\n## 2. Objectives\n\nB1 fewer errors.\n' >> "$work/PRD.md"
assert_exit 0 rs doc-put PP --title "PRD: Clinic portal" --file "$work/PRD.md" --type prd --source docs/product/PRD.md
assert_contains "$T_OUT" '"action":"updated"'
assert_exit 0 rs doc-get "$DOC"
assert_contains "$T_OUT" "B1 fewer errors."
assert_exit 0 rs doc-put PP --title "PRD: Clinic portal v2" --file "$work/PRD.md" --type prd --source docs/product/PRD.md
assert_contains "$T_OUT" '"action":"updated"'
assert_contains "$T_OUT" "\"id\":$DOC"
assert_eq 1 "$(state "['documents']")" "documents after create, rerun, edit and rename"
t_end

t_begin "--parent nests a document"
printf '# Architecture decisions\n\nOne entry per ADR.\n' > "$work/adr-index.md"
printf '# ADR-0001: Host on Vercel\n\nAccepted.\n' > "$work/0001.md"
assert_exit 0 rs doc-put PP --title "Architecture decisions" --file "$work/adr-index.md" --type design --source docs/adr
PARENT="$(printf '%s' "$T_OUT" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)"
assert_exit 0 rs doc-put PP --title "ADR-0001: Host on Vercel" --file "$work/0001.md" --type design --parent "$PARENT" --source docs/adr/0001.md
assert_contains "$T_OUT" '"action":"created"'
CHILD="$(printf '%s' "$T_OUT" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)"
assert_exit 0 rs doc-get "$CHILD"
assert_contains "$T_OUT" "\"parent_id\": $PARENT"
assert_exit 0 rs docs PP --type design
assert_contains "$T_OUT" "2 document(s) in PP"
t_end

t_begin "a create answered 502 after it applied leaves one document"
printf '# Coverage\n\nAll covered.\n' > "$work/coverage.md"
ctl POST "/_fault?mode=after" >/dev/null
before="$(state "['documents']")"
assert_exit 0 rs doc-put PP --title "Coverage" --file "$work/coverage.md" --source docs/product/coverage.md
assert_contains "$T_OUT" "answered 502 but had been applied; not sent again"
assert_eq $((before + 1)) "$(state "['documents']")" "documents after one faulted create"
t_end

t_begin "create and update --document point a story at the PRD"
assert_exit 0 rs create PP --type story --title "File a lab report" --document "$DOC"
KEY="$(printf '%s' "$T_OUT" | sed -n 's/.*"key": *"\([^"]*\)".*/\1/p' | head -1)"
assert_eq "$DOC" "$(state "['document_ids']['$KEY']")" "document_id of the created story"
assert_exit 0 rs update PP-17 --document "$DOC"
assert_eq "$DOC" "$(state "['document_ids']['PP-17']")" "document_id of the updated story"
assert_exit 1 rs update PP-17 --document abc
assert_contains "$T_OUT" "--document is a document id"
t_end

t_begin "refused before any call: empty file, unknown type, non-numeric ids"
: > "$work/empty.md"
n="$(wc -l < "$LOG")"
assert_exit 1 rs doc-put PP --title "Empty" --file "$work/empty.md"
assert_contains "$T_OUT" "is empty; an empty document is not published"
assert_exit 1 rs doc-put PP --title "Bad" --file "$work/PRD.md" --type wiki
assert_contains "$T_OUT" "type must be prd|design|doc"
assert_exit 1 rs doc-put PP --title "Bad" --file "$work/PRD.md" --parent x1
assert_contains "$T_OUT" "--parent is a document id"
assert_exit 1 rs doc-get PP-17
assert_contains "$T_OUT" "a document id is a number"
assert_eq "$n" "$(wc -l < "$LOG" | tr -d ' ')" "no request for refused input"
t_end

t_begin "brg-tracker: rest passes document commands through; other trackers and none skip with exit 3"
TR="$KIT/plugins/bearing/bin/brg-tracker"
tr_as() { local t="$1"; shift; env -u BEARING_TRACKER_PASSWORD -u BEARING_TRACKER_EMAIL BEARING_ENV=/nonexistent XDG_CONFIG_HOME="$cfg" HOME="$home" \
  BEARING_TRACKER="$t" BEARING_TRACKER_URL="$URL" BEARING_TRACKER_TOKEN="$TOKEN" BEARING_TRACKER_PROJECT=PP bash "$TR" "$@"; }
assert_exit 0 tr_as rest docs --type design
assert_contains "$T_OUT" "2 document(s) in PP"
assert_exit 0 tr_as rest doc-put --title "PRD: Clinic portal v2" --file "$work/PRD.md" --type prd --source docs/product/PRD.md
assert_contains "$T_OUT" '"action":"unchanged"'
assert_exit 0 tr_as rest create --type story --title "Via the front" --document "$DOC"
assert_exit 3 tr_as jira doc-put --title "PRD" --file "$work/PRD.md"
assert_contains "$T_OUT" "documents: not supported by the jira tracker"
assert_exit 3 tr_as none doc-put --title "PRD" --file "$work/PRD.md"
assert_exit 0 tr_as none docs
assert_contains "$T_OUT" "tracker: none"
t_end

t_begin "a server without documents is named in one line and nothing is posted"
ctl POST /_nodocs >/dev/null
assert_exit 1 rs docs PP
assert_contains "$T_OUT" "this tracker does not support documents"
n="$(posts)"
assert_exit 1 rs doc-put PP --title "PRD" --file "$work/PRD.md" --type prd
assert_contains "$T_OUT" "this tracker does not support documents"
assert_eq 1 "$(printf '%s\n' "$T_OUT" | grep -c 'brg-rest:')" "one error line"
assert_eq "$n" "$(posts)" "no POST to a server without documents"
t_end

t_summary
