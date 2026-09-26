#!/usr/bin/env bash
# tests/unit/deliverables_pack.sh: skills/client-deliverables/scripts/pack.py and
# md2docx.py. A small repository is packed into the twelve folders: versioned
# Word documents with a cover and history, CSV from the named tables, folder
# READMEs, the top README of current versions, the changelog and the
# delivery checklist workbook. A rebuild with no change bumps nothing; one
# changed source bumps only its artifact and counts what changed; a person's
# checklist status survives evidence; an empty repository and a target
# outside the repository are refused. Word and Excel need python-docx and
# openpyxl through uv; without uv the pack must fail and say why.
set -u
. "$(dirname "$0")/../lib/assert.sh"
P="$KIT/skills/client-deliverables/scripts/pack.py"

repo() { # a repository with a few Bearing artifacts
  mkdir -p "$1/docs/product" "$1/docs/testing" "$1/docs/design" "$1/.bearing"
  printf '{"delivering_entity": "Example Co Private Limited"}\n' > "$1/.bearing/company.json"
  printf '# PRD: Orders\n\n<!-- internal: estimate padded 30%% -->\n## 1. Problem\n\nCustomers cannot see **invoices**.\n\n- REQ-001 list invoices\n' > "$1/docs/product/PRD.md"
  printf '# Backlog\n\n## US-01-001 List invoices\n\n| AC | Given | Then |\n| --- | --- | --- |\n| AC-US-01-001-1 | a customer | invoices show |\n' > "$1/docs/product/backlog.md"
  { printf '# Test cases\n\n| TC | Story | ACs | Title |\n| --- | --- | --- | --- |\n'
    printf '| TC-0001 | US-01-001 | AC-US-01-001-1 | Lists invoices |\n'; } > "$1/docs/testing/test-cases.md"
  printf '# Orders HLD\n\nDiagram: docs/architecture/diagrams/OrdersHub_SystemArchitecture_v1.svg\n\n## 1. Goal\n\nShip it.\n\n```mermaid\nflowchart LR\n  a --> b\n```\n' > "$1/docs/design/orders-hld.md"
}
run_pack() { (cd "$1" && shift && if command -v uv >/dev/null; then uv run --quiet --with python-docx --with openpyxl python3 "$P" "$@"; else python3 "$P" "$@"; fi); }

t_begin "a repository packs into the twelve folders"
d="$(tmpdir)/orders-hub"; repo "$d"
if command -v uv >/dev/null; then
  assert_exit 0 run_pack "$d" --project orders-hub --customer "Example Customer" --date 2026-09-01
  o="$d/deliverables/OrdersHub_ProjectDocumentation"
  assert_contains "$T_OUT" "pack: 4 artifacts (4 new versions"
  assert_contains "$T_OUT" "4 Word documents, 1 CSV"
  for f in 01_Product 06_QA 12_Meeting_Notes; do assert_file "$o/$f/README.md"; done
  assert_file "$o/01_Product/OrdersHub_Requirements_v1.docx"
  assert_file "$o/03_Architecture/OrdersHub_HLD_v1.docx"
  assert_file "$o/OrdersHub_DeliveryChecklist_2026-09-01.xlsx"
  assert_file "$o/01_Product/PRD.md"
  assert_not_contains "$(cat "$o/01_Product/PRD.md")" "internal: estimate"
  assert_contains "$(cat "$o/01_Product/PRD.md")" "REQ-001 list invoices"
  assert_eq "TC,Story,ACs,Title" "$(head -1 "$o/06_QA/test-cases.csv" | tr -d '\r')" "CSV header"
  assert_contains "$(cat "$o/README.md")" "| Test Cases | v1 | 2026-09-01: First issue |"
  assert_contains "$(cat "$o/CHANGELOG.md")" "High-Level Design v1, First issue (Example Co Private Limited)"
  assert_contains "$T_OUT" "checklist: 154 tasks"
  cover="$(cd "$d" && uv run --quiet --with python-docx python3 -c 'import docx,sys; d=docx.Document(sys.argv[1]); print("|".join(c.text for t in d.tables[:1] for r in t.rows for c in r.cells))' "$o/01_Product/OrdersHub_Requirements_v1.docx")"
  assert_contains "$cover" "Prepared by|Example Co Private Limited"
  assert_contains "$cover" "Customer|Example Customer"
else
  assert_exit 1 run_pack "$d" --project orders-hub
  assert_contains "$T_OUT" "python-docx is not installed"
fi
t_end

if command -v uv >/dev/null; then
t_begin "a rebuild bumps only what changed, and says what changed"
d="$(tmpdir)/orders-hub"; repo "$d"
run_pack "$d" --project orders-hub --date 2026-09-01 >/dev/null
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-02
assert_contains "$T_OUT" "(0 new versions"
printf '| TC-0002 | US-01-001 | AC-US-01-001-1 | Empty list |\n' >> "$d/docs/testing/test-cases.md"
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-03
assert_contains "$T_OUT" "(1 new versions"
o="$d/deliverables/OrdersHub_ProjectDocumentation"
assert_file "$o/06_QA/OrdersHub_TestCases_v2.docx"
assert_contains "$(cat "$o/README.md")" "| Test Cases | v2 | 2026-09-03: 1 added |"
printf -- '- REQ-002: export overdue invoices\n' >> "$d/docs/product/PRD.md"
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-04
assert_contains "$(cat "$o/README.md")" "| Product Requirements | v2 | 2026-09-04: 1 added |"
t_end

t_begin "a person's checklist status survives; evidence marks the rest"
d="$(tmpdir)/orders-hub"; repo "$d"
run_pack "$d" --project orders-hub --date 2026-09-01 >/dev/null
x="$d/deliverables/OrdersHub_ProjectDocumentation/OrdersHub_DeliveryChecklist_2026-09-01.xlsx"
(cd "$d" && uv run --quiet --with openpyxl python3 - "$x" <<'PY'
import openpyxl, sys
wb = openpyxl.load_workbook(sys.argv[1]); ws = wb["Project Checklist"]
for r in ws.iter_rows(min_row=5):
    if r[2].value and r[2].value.startswith("Prepare the High-Level Design"):
        r[4].value, r[7].value = "Blocked", "waiting on the client"
wb.save(sys.argv[1] + ".filled.xlsx")
PY
)
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-02 --import-checklist "$x.filled.xlsx"
assert_contains "$T_OUT" "set by people"
state="$(cat "$d/docs/deliverables/checklist.json")"
assert_contains "$state" '"status": "Blocked"'
assert_contains "$state" '"remarks": "waiting on the client"'
assert_contains "$state" '"remarks": "evidence: docs/product/PRD.md"'
t_end
t_begin "the pack is ignored by an anchored rule; docs/deliverables stays committable"
d="$(tmpdir)/orders-hub"; repo "$d"; git -C "$d" init -q
printf 'node_modules/\ndeliverables/\n' > "$d/.gitignore"
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-01
assert_contains "$T_OUT" "pack: .gitignore: rewrote the unanchored deliverables/ rule to /deliverables/"
assert_eq "node_modules/,/deliverables/" "$(paste -sd, "$d/.gitignore")" ".gitignore after the rewrite"
assert_exit 1 git -C "$d" check-ignore -q docs/deliverables/versions.json
assert_exit 1 git -C "$d" check-ignore -q docs/deliverables/checklist.json
assert_exit 0 git -C "$d" check-ignore -q deliverables/OrdersHub_ProjectDocumentation/README.md
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-02
assert_not_contains "$T_OUT" "pack: .gitignore:"
assert_eq "1" "$(grep -c '^/deliverables/$' "$d/.gitignore")" "one anchored rule after a rebuild"
t_end
fi

t_begin "an empty repository and a target outside it are refused"
d="$(tmpdir)/empty"; mkdir -p "$d"
assert_exit 1 run_pack "$d" --project empty
assert_contains "$T_OUT" "0 artifact sources found"
d="$(tmpdir)/orders-hub"; repo "$d"
assert_exit 1 run_pack "$d" --project orders-hub --out /tmp
assert_contains "$T_OUT" "refusing to replace /tmp"
t_end

t_summary
