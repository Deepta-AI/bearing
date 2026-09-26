#!/usr/bin/env bash
# tests/unit/architecture_diagram.sh: skills/architecture-diagram/scripts
# render.py (the system, flow and deployment views from architecture.json,
# versioned file names, numbered connections and a legend) and
# diagram_check.py (every node and link drawn, no text overlapping or
# clipped, no line through a node or a label, no two connections on one
# line), each with its empty-input failure. PNG is not rendered here.
set -u
. "$(dirname "$0")/../lib/assert.sh"
R="$KIT/skills/architecture-diagram/scripts/render.py"
C="$KIT/skills/architecture-diagram/scripts/diagram_check.py"
M="$KIT/tests/fixtures/architecture/architecture.json"

t_begin "the fixture renders three views that pass the gate"
d="$(tmpdir)"
assert_exit 0 python3 "$R" --model "$M" --out "$d" --no-png
assert_contains "$T_OUT" "render: 3 views, 16 nodes, 16 connections, PNG not requested"
assert_file "$d/OrdersHub_SystemArchitecture_v2.svg"
assert_file "$d/OrdersHub_ArchitectureFlow_v2.svg"
assert_file "$d/OrdersHub_DeploymentArchitecture_v2.svg"
assert_contains "$(cat "$d/OrdersHub_SystemArchitecture_v2.svg")" "WHAT EACH CONNECTION CARRIES"
assert_contains "$(cat "$d/OrdersHub_SystemArchitecture_v2.svg")" "unconfirmed:"
assert_exit 0 python3 "$C" --model "$M" --dir "$d"
assert_contains "$T_OUT" "diagram-check: 3 diagrams, 26 nodes, 27 connections"
assert_contains "$T_OUT" " 0 problems"
t_end

t_begin "a broken model is refused before anything is drawn"
d="$(tmpdir)"
python3 - "$M" "$d/bad.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
m["system_diagram"]["links"].append({"from": "api", "to": "nowhere", "label": "x"})
json.dump(m, open(sys.argv[2], "w"))
PY
assert_exit 1 python3 "$R" --model "$d/bad.json" --out "$d/out" --no-png
assert_contains "$T_OUT" "names unknown node 'nowhere'"
printf '{"project": "empty", "system_diagram": {"tiers": [], "links": []}}\n' > "$d/empty.json"
assert_exit 1 python3 "$R" --model "$d/empty.json" --out "$d/out" --no-png
assert_contains "$T_OUT" "0 nodes"
t_end

t_begin "the gate catches overlap, a line through a node, a missing legend row and a bad name"
d="$(tmpdir)"
python3 "$R" --model "$M" --out "$d" --no-png >/dev/null
f="$d/OrdersHub_SystemArchitecture_v2.svg"
# move the title onto the first tier header
python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
m = re.search(r'<text [^>]*data-box="([^"]+)"[^>]*>CLIENT APPLICATIONS</text>', s)
s = re.sub(r'(<text [^>]*data-box=")[^"]+("[^>]*>OrdersHub: System Architecture</text>)', r"\g<1>" + m.group(1) + r"\2", s)
open(p, "w").write(s)
PY
assert_exit 1 python3 "$C" --model "$M" --dir "$d"
assert_contains "$T_OUT" "overlaps 'CLIENT APPLICATIONS'"
python3 "$R" --model "$M" --out "$d" --no-png >/dev/null
# route connection 1 straight through the Back office node
python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
m = re.search(r'<g data-node="admin"><rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"', s)
x, y, w, h = (float(v) for v in m.groups())
s = re.sub(r'd="[^"]*"( [^>]*data-edge="1")', f'd="M{x - 20} {y + h / 2} L{x + w + 20} {y + h / 2}"' + r"\1", s)
s = s.replace('<g data-legend="2">', '<g data-legend-gone="2">')
open(p, "w").write(s)
PY
assert_exit 1 python3 "$C" --model "$M" --dir "$d"
assert_contains "$T_OUT" "connection 1 (web to gw) passes through node 'admin'"
assert_contains "$T_OUT" "connection 2 has no legend row"
mv "$f" "$d/system-architecture.svg"
assert_exit 1 python3 "$C" --model "$M" --dir "$d"
assert_contains "$T_OUT" "file name is not <Project>_<View>_v<N>.svg"
t_end

t_begin "no diagrams, or no model, fails"
d="$(tmpdir)"
assert_exit 1 python3 "$C" --model "$M" --dir "$d"
assert_contains "$T_OUT" "0 SVG files"
assert_exit 1 python3 "$C" --model "$d/none.json" --dir "$d"
assert_contains "$T_OUT" "cannot read"
t_end

t_summary
