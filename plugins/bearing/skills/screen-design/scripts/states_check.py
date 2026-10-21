#!/usr/bin/env python3
"""states_check: every screen prototype renders every state its inventory lists.

The inventory is section 2 ("Interaction states") of the flows file: one
"### S-nn <name>" heading per screen and a table of states under it; a row
whose second cell starts with "n/a" is out of scope. With no flows file,
each screen must render the five baseline states (loading, empty, error,
success, partial) unless the page carries <!-- n/a: <state> because ... -->.

A screen's prototype is <screens dir>/<id>-<name>.html (S-01-orders.html).
Its states are the values of data-state="..." on its panels; each panel also
needs a control that reaches it (data-state-target="...", a repo's own
data-target="...", or an href="#state=..." link), and the file must hold no
unfilled {{PLACEHOLDER}}. State names compare case-blind with spaces and
underscores read as hyphens, so the flows' "no slots" is the page's
"no-slots": a repository's existing mockups are checked as they are, never
rewritten to suit this gate.

Usage: states_check.py --screens <dir> [--flows <flows.md>] [--only S-01,S-03]
Prints one line per problem and the counts; exits 1 on any problem, or when
zero screens were checked.

Needs mode: states_check.py --needs <data-needs.md> --flows <flows.md> checks
the feature's data-needs.md against the flows inventory (see needs_main);
A screen with a server field or a server condition must list at least one
action whose Server is not none: (the read that loads it).
parse_needs and outcomes are importable for the contract checks.
"""

import argparse
import glob
import importlib.util
import os
import re
import sys

BASELINE = ["loading", "empty", "error", "success", "partial"]


def norm(state):
    """One spelling per state: lower case; spaces, underscores, colons and
    brackets as hyphens ("error: slot_unavailable" is error-slot-unavailable,
    "error (409)" is error-409)."""
    return re.sub(r"[\s_:()]+", "-", state.strip().lower()).strip("-")


def row_counts(flows_path):
    """{screen id: {state: rows}}: how many rows of section 2 carry each
    state, so a screen with three bare "error" rows is known to need three
    error states, not one."""
    text = open(flows_path, encoding="utf-8").read()
    m = re.search(r"^## 2\. .*?$(.*?)(?=^## \d+\. |\Z)", text, re.M | re.S)
    out, cur = {}, None
    for line in (m.group(1) if m else "").split("\n"):
        h = re.match(r"^###\s+(S-\d{2,3})\b", line)
        if h:
            cur = h.group(1)
            out[cur] = {}
            continue
        if cur is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0].lower() in ("state", "") or set(cells[0]) <= set("-: "):
            continue
        if cells[1].lower().startswith("n/a"):
            continue
        state = norm(re.sub(r"[`*]", "", cells[0]))
        if state:
            out[cur][state] = out[cur].get(state, 0) + 1
    return out


def inventory(flows_path):
    """{screen id: [states]} from section 2 of the flows file."""
    text = open(flows_path, encoding="utf-8").read()
    m = re.search(r"^## 2\. .*?$(.*?)(?=^## \d+\. |\Z)", text, re.M | re.S)
    if not m:
        return {}
    screens, cur = {}, None
    for line in m.group(1).split("\n"):
        h = re.match(r"^###\s+(S-\d{2,3})\b", line)
        if h:
            cur = h.group(1)
            screens[cur] = []
            continue
        if cur is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if (
            len(cells) < 2
            or cells[0].lower() in ("state", "")
            or set(cells[0]) <= set("-: ")
        ):
            continue
        if cells[1].lower().startswith("n/a"):
            continue
        state = norm(re.sub(r"[`*]", "", cells[0]))
        if state and state not in screens[cur]:
            screens[cur].append(state)
    return screens


def screen_file(screens_dir, sid):
    for pat in (
        f"{sid}-*.html",
        f"{sid.lower()}-*.html",
        f"{sid.replace('-', '')}*.html",
    ):
        hits = sorted(glob.glob(os.path.join(screens_dir, pat)))
        if hits:
            return hits[0]
    return None

NEEDS_KINDS = {"fields": "fields", "actions": "actions", "states": "states"}
STATUSES = ("exists", "new")


def parse_needs(text):
    """{sid: {"fields": [...], "actions": [...], "states": [...]}} from the
    "## S-nn <name>" sections of a data-needs.md. Each row is a dict keyed by
    the lower-cased table headers; a row whose first cell starts "none:" is
    {"none": "<reason>"}."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    out, sid, kind, header = {}, None, None, None
    for line in text.split("\n"):
        h2 = re.match(r"^##\s+(S-\d{2,3})\b", line)
        if h2:
            sid, kind, header = h2.group(1), None, None
            out.setdefault(sid, {"fields": [], "actions": [], "states": []})
            continue
        if re.match(r"^##\s", line):
            sid, kind, header = None, None, None
            continue
        h3 = re.match(r"^###\s+(\w+)", line)
        if h3:
            kind = NEEDS_KINDS.get(h3.group(1).lower())
            header = None
            continue
        if sid is None or kind is None or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if cells[0] and set(cells[0]) <= set("-: "):
            continue
        first = re.sub(r"[`*]", "", cells[0]).strip()
        if first.lower().startswith("none:"):
            out[sid][kind].append({"none": first[5:].strip()})
            continue
        if not any(cells):
            continue
        row = {header[i]: (cells[i] if i < len(cells) else "") for i in range(len(header))}
        out[sid][kind].append(row)
    return out


def outcomes(cell):
    """[(status, code)] from "201 created; 409 already_member". A token with
    no leading status keeps an empty status; a bare status keeps an empty
    code, so the caller can say which half is missing."""
    res = []
    for tok in re.split(r"[;\n]", cell or ""):
        tok = re.sub(r"[`*]", "", tok).strip()
        if not tok:
            continue
        m = re.match(r"^(\d{3})\b\s*(.*)$", tok)
        res.append((m.group(1), m.group(2).strip()) if m else ("", tok))
    return res


def _flows_check():
    path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..", "ux-flows", "scripts", "flows_check.py"
    )
    spec = importlib.util.spec_from_file_location("flows_check", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def needs_main(needs_path, flows_path):
    if not flows_path or not os.path.isfile(flows_path):
        print(f"data-needs: flows file {flows_path} not found, nothing checked", file=sys.stderr)
        return 1
    if not os.path.isfile(needs_path):
        print(f"data-needs: {needs_path} not found, nothing checked", file=sys.stderr)
        return 1
    screens = _flows_check().inventory_full(open(flows_path, encoding="utf-8").read())[0]
    if not screens:
        print(f"data-needs: 0 screens in the inventory ({flows_path}), nothing checked", file=sys.stderr)
        return 1
    needs = parse_needs(open(needs_path, encoding="utf-8").read())
    states = inventory(flows_path)
    problems, nf, na, nex, nnew, no, ns = [], 0, 0, 0, 0, 0, 0
    seen = {}

    def status_ok(label, row, allow_blank):
        st = row.get("status", "").strip().lower()
        if st in STATUSES or (allow_blank and not st):
            return True
        problems.append(f"{label} status must be exists or new")
        return False

    for sid in screens:
        if sid not in needs:
            problems.append(f"{sid} has no entry in {needs_path}")
            continue
        entry = needs[sid]
        for kind in ("fields", "actions", "states"):
            for r in entry[kind]:
                if "none" in r and not r["none"]:
                    problems.append(f"{sid} {kind}: none needs a reason (write none: <reason>)")
        for r in entry["fields"]:
            if "none" in r:
                continue
            nf += 1
            fid = r.get("id", "").strip()
            label = f"{fid or 'field'} ({sid})"
            if not re.match(r"^F-\d+$", fid):
                problems.append(f"{label}: field id must be F-<digits>, got \"{fid}\" in {sid}")
            src = r.get("source", "").strip().lower()
            if not (src == "server" or re.match(r"^(derived|client):\s*\S", src)):
                problems.append(f"{label} source must be server, derived: <how> or client: <where>")
            status_ok(label, r, src.startswith("client"))
        for r in entry["actions"]:
            if "none" in r:
                continue
            na += 1
            aid = r.get("id", "").strip()
            label = f"{aid or 'action'} ({sid})"
            if not re.match(r"^A-\d+$", aid):
                problems.append(f"{label}: action id must be A-<digits>, got \"{aid}\" in {sid}")
            else:
                seen.setdefault(aid, []).append(sid)
            server = r.get("server", "").strip()
            m = re.match(r"^none:\s*(.*)$", server, re.I)
            if m and not m.group(1).strip():
                problems.append(f"{label} none needs a reason (write none: <reason>)")
            client = bool(m)
            status_ok(label, r, client)
            st = r.get("status", "").strip().lower()
            if st == "exists":
                nex += 1
            elif st == "new":
                nnew += 1
            if client:
                continue
            outs = outcomes(r.get("outcomes", ""))
            if not outs:
                problems.append(f"{label} has no outcome")
            for status, code in outs:
                no += 1
                if not status:
                    problems.append(f'{label} outcome "{code}" has no status (write <status> <code>)')
                elif not code:
                    problems.append(f'{label} outcome "{status}" has no code (write <status> <code>)')
        have = {}
        for r in entry["states"]:
            if "none" in r:
                continue
            ns += 1
            have[norm(re.sub(r"[`*]", "", r.get("state", "")))] = r.get("server condition", "").strip()
        for s in states.get(sid, []):
            if re.match(r"^(error|empty|loading)(-|$)", s) and not have.get(s):
                problems.append(f"{sid} state {s} has no server condition")
        # a screen that shows server data owes the read that loads it: the
        # contract is derived from the actions, so an unlisted read has no API
        shows = any(
            "none" not in r and r.get("source", "").strip().lower() == "server" for r in entry["fields"]
        ) or any(have.values())
        asks = any(
            "none" not in r and not re.match(r"^none:", r.get("server", "").strip(), re.I)
            for r in entry["actions"]
        )
        if shows and not asks:
            problems.append(
                f"{sid} shows server data (a server field or a server condition) but has no server "
                f"action: list the read that loads it, marked exists when the API already has it"
            )
    for aid, where in seen.items():
        if len(where) > 1:
            problems.append(f"{aid} is used twice ({', '.join(where)})")

    if na == 0:
        problems.append(f"0 actions in {needs_path}: a feature with no action has nothing for the API to answer")
    for p in problems:
        print(f"problem: {p}")
    print(
        f"data-needs: {len(screens)} screens, {nf} fields, {na} actions ({nex} exists, {nnew} new), "
        f"{no} outcomes, {ns} states, {len(problems)} problems"
    )
    return 1 if problems else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--screens")
    ap.add_argument("--needs")
    ap.add_argument("--flows")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    if a.needs:
        if not a.flows:
            print("states_check: --flows is required with --needs", file=sys.stderr)
            return 2
        return needs_main(a.needs, a.flows)
    if not a.screens:
        ap.error("--screens is required (or --needs with --flows)")

    only = [s.strip() for s in a.only.split(",") if s.strip()]
    if a.flows and os.path.isfile(a.flows):
        inv = inventory(a.flows)
        source = a.flows
    else:
        files = sorted(glob.glob(os.path.join(a.screens, "S-*.html")))
        inv = {
            re.match(r"(S-\d{2,3})", os.path.basename(f)).group(1): None
            for f in files
            if re.match(r"S-\d{2,3}", os.path.basename(f))
        }
        source = "baseline five (no flows file)"
    if only:
        inv = {k: v for k, v in inv.items() if k in only}
    if not inv:
        print(
            f"screen-states: 0 screens in the inventory ({source}), nothing checked",
            file=sys.stderr,
        )
        return 1

    problems, panels_total, complete = [], 0, 0
    for sid, want in inv.items():
        path = screen_file(a.screens, sid)
        if not path:
            problems.append(f"{sid}: no prototype in {a.screens}")
            continue
        html = open(path, encoding="utf-8").read()
        name = os.path.basename(path)
        panels = re.findall(r'\bdata-state="([^"]+)"', html)
        targets = set(
            norm(t)
            for t in re.findall(r'\bdata-(?:state-)?target="([^"]+)"', html)
            + re.findall(r'href="#state=([^"&]+)"', html)
        )
        panels_total += len(panels)
        if want is None:
            exempt = set(
                s.lower() for s in re.findall(r"<!--\s*n/a:\s*([a-z-]+)\b", html, re.I)
            )
            want = [s for s in BASELINE if s not in exempt]
        have = set(norm(p) for p in panels)
        missing = [s for s in want if s not in have]
        for s in missing:
            problems.append(f'{sid} ({name}): no data-state="{s}" panel')
        for p in panels:
            if norm(p) not in targets:
                problems.append(
                    f"{sid} ({name}): panel {p} has no state-bar button (data-state-target)"
                )
        holes = sorted(set(re.findall(r"\{\{[A-Z_#/]+\}\}", html)))
        if holes:
            problems.append(
                f"{sid} ({name}): unfilled placeholders {', '.join(holes[:5])}"
            )
        if not missing:
            complete += 1

    for p in problems:
        print(f"problem: {p}")
    print(
        f"screen-states: {len(inv)} screens from {source}, {panels_total} state panels, "
        f"{complete} of {len(inv)} screens with all inventory states, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
