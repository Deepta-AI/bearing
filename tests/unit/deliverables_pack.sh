#!/usr/bin/env bash
# tests/unit/deliverables_pack.sh: plugins/bearing/skills/client-deliverables/scripts/pack.py and
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
P="$KIT/plugins/bearing/skills/client-deliverables/scripts/pack.py"

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
assert_contains "$(cat "$o/README.md")" "| Test Cases | v2 | 2026-09-03: added TC-0002 |"
printf -- '- REQ-002: export overdue invoices\n' >> "$d/docs/product/PRD.md"
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-04
assert_contains "$(cat "$o/README.md")" "| Product Requirements | v2 | 2026-09-04: added REQ-002 |"
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
assert_contains "$state" '"remarks": "evidence: docs/product/PRD.md, docs/product/backlog.md"'
# the HLD file exists, but the person's Blocked holds every task standing on it
assert_contains "$T_OUT" "pack: held 'HLD: System Architecture and Service Boundaries': Blocked"
assert_not_contains "$T_OUT" "held 'HLD, LLD, Architecture Diagram"
assert_contains "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["HLD, LLD, Architecture Diagram and Database Design filed and current"])' "$d/docs/deliverables/checklist.json")" "Not Started"
# a held status read back unchanged stays the script's, so it lifts with the block
(cd "$d" && uv run --quiet --with openpyxl python3 - "$d/deliverables/OrdersHub_ProjectDocumentation/OrdersHub_DeliveryChecklist_2026-09-02.xlsx" <<'PY'
import openpyxl, sys
wb = openpyxl.load_workbook(sys.argv[1]); ws = wb["Project Checklist"]
for r in ws.iter_rows(min_row=5):
    if r[2].value and r[2].value.startswith("Prepare the High-Level Design"):
        r[4].value, r[7].value = "Completed", "unblocked"
wb.save(sys.argv[1] + ".2.xlsx")
PY
)
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-03 --import-checklist "$d/deliverables/OrdersHub_ProjectDocumentation/OrdersHub_DeliveryChecklist_2026-09-02.xlsx.2.xlsx"
assert_contains "$T_OUT" "0 held by a person's status"
assert_contains "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["HLD: System Architecture and Service Boundaries"])' "$d/docs/deliverables/checklist.json")" "'status': 'Completed'"
t_end

t_begin "a renamed task keeps a person's status; no internal tool name reaches the client"
d="$(tmpdir)/orders-hub"; repo "$d"
mkdir -p "$d/docs/deliverables"
printf '{"Prepare UI/UX designs using Claude Design": {"status": "Blocked", "by": "person", "owner": "Asha"}}\n' > "$d/docs/deliverables/checklist.json"
assert_exit 0 run_pack "$d" --customer "Example Customer" --date 2026-09-01
o="$d/deliverables/Orders_ProjectDocumentation"
assert_file "$o/01_Product/Orders_Requirements_v1.docx" # named from the PRD title, not the folder
state="$(cat "$d/docs/deliverables/checklist.json")"
assert_not_contains "$state" "Claude Design"
assert_contains "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Prepare the UI/UX screen designs"])' "$d/docs/deliverables/checklist.json")" "'owner': 'Asha'"
scan="$(cd "$o" && uv run --quiet python3 - <<'PY'
import os, re, zipfile
n, hits = 0, set()
for root, _, files in os.walk("."):
    for f in files:
        p = os.path.join(root, f)
        if f.endswith((".docx", ".xlsx")):
            z = zipfile.ZipFile(p)
            text = "".join(z.read(x).decode("utf-8", "replace") for x in z.namelist() if x.endswith(".xml"))
        elif f.endswith((".md", ".csv")):
            text = open(p, encoding="utf-8").read()
        else:
            continue
        n += 1
        hits |= {m.lower() for m in re.findall(r"(?i)claude|bearing|vapt-report|client-deliverables|filled by", text)}
print(n, ",".join(sorted(hits)))
PY
)"
assert_contains "$scan" "$(cd "$o" && find . -name '*.docx' -o -name '*.xlsx' -o -name '*.md' -o -name '*.csv' | wc -l) "
leak="${scan#* }"
assert_eq "" "$leak" "internal tool names in the client files"
t_end

t_begin "leftovers are listed with file and line; a Mermaid flowchart is written out in words"
d="$(tmpdir)/orders-hub"; repo "$d"
printf -- '- REQ-002: overdue badge. TBD: wording\n' >> "$d/docs/product/PRD.md"
assert_exit 0 run_pack "$d" --customer "Example Customer" --date 2026-09-01
assert_contains "$T_OUT" "pack: leftover docs/product/PRD.md:9: - REQ-002: overdue badge. TBD: wording"
assert_contains "$T_OUT" "1 leftovers in the client files"
assert_not_contains "$T_OUT" "internal: estimate"
body="$(cd "$d" && uv run --quiet --with python-docx python3 -c 'import docx,sys; print("|".join(p.text for p in docx.Document(sys.argv[1]).paragraphs))' deliverables/Orders_ProjectDocumentation/03_Architecture/Orders_HLD_v1.docx)"
assert_contains "$body" "a to b"
assert_not_contains "$body" "flowchart"
assert_not_contains "$body" "open the Markdown"
# the engineer holds the TBD line back: gone from the client copies, source untouched
assert_exit 0 run_pack "$d" --customer "Example Customer" --date 2026-09-02 --hold docs/product/PRD.md:9
assert_contains "$T_OUT" "pack: held back docs/product/PRD.md:9 from the client copies (source unchanged)"
assert_contains "$T_OUT" "0 leftovers in the client files"
assert_contains "$(cat "$d/docs/product/PRD.md")" "TBD: wording"
assert_not_contains "$(cat "$d/deliverables/Orders_ProjectDocumentation/01_Product/PRD.md")" "TBD"
body="$(cd "$d" && uv run --quiet --with python-docx python3 -c 'import docx,sys; print("|".join(p.text for p in docx.Document(sys.argv[1]).paragraphs))' deliverables/Orders_ProjectDocumentation/01_Product/Orders_Requirements_v2.docx)"
assert_contains "$body" "REQ-001"
assert_not_contains "$body" "TBD"
assert_exit 1 run_pack "$d" --hold docs/product/PRD.md:999
t_end
t_begin "the pack is ignored by an anchored rule; docs/deliverables stays committable"
d="$(tmpdir)/orders-hub"; repo "$d"; git -C "$d" init -q
printf 'node_modules/\ndeliverables/\n' > "$d/.gitignore"
assert_exit 0 run_pack "$d" --project orders-hub --date 2026-09-01
assert_contains "$T_OUT" "pack: .gitignore: rewrote the unanchored deliverables/ rule to /deliverables/"
assert_eq "node_modules/,/deliverables/" "$(paste -sd, "$d/.gitignore")" ".gitignore after the rewrite"
assert_exit 1 git -C "$d" check-ignore -q docs/deliverables/versions.json
assert_exit 1 git -C "$d" check-ignore -q docs/deliverables/checklist.json
assert_exit 0 git -C "$d" check-ignore -q deliverables/Orders_ProjectDocumentation/README.md
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
