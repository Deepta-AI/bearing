#!/usr/bin/env python3
"""render: draw the architecture views in docs/architecture/architecture.json
as SVG, and as PNG where a headless Chrome is installed.

The model:

  {"project": "Orders", "version": 3,
   "system_diagram": {
     "tiers": [{"name": "Client applications",
                "groups": [{"name": "Web workspace", "kind": "client",
                            "nodes": [{"id": "web", "name": "Customer web app",
                                       "kind": "app", "tech": "React",
                                       "modules": ["Checkout", "Account"],
                                       "owns_store": false}]}]}],
     "links": [{"from": "web", "to": "api", "label": "REST over HTTPS",
                "kind": "sync"}]},
   "deployment_diagram": { same shape: tiers are zones, groups are hosts or
                           clusters, nodes are containers and managed services }}

Group kinds colour the group: client, gateway, services, data, external,
messaging. Node kinds: app, service, store, queue, external, job. Link kinds:
sync (solid, a request and its reply), async (dashed, an event or a message),
bulk (dotted, bulk or scheduled data). A link with "unconfirmed": true says
so in its legend row.

Views written, each <Project>_<View>_v<version>.svg (and .png):
  SystemArchitecture   tiers as columns, groups and modules drawn inside
  ArchitectureFlow     the same model as horizontal bands, no modules
  DeploymentArchitecture  from deployment_diagram, when the model has one

Layout rules that keep the picture legible, and that diagram_check.py proves
from the SVG afterwards: every connection leaves its node into the gutter
beside the tier and runs in a lane of its own there, so no line crosses a
node; a connection that skips a tier climbs to a routing band outside the
content; no label sits on a line: each connection carries a numbered badge
in its own lane and the legend says what it carries. Text is wrapped to its
box, never clipped.

Usage: render.py [--model docs/architecture/architecture.json]
                 [--out docs/architecture/diagrams] [--no-png]
Prints one line per file and a counts line; exits 1 on a model with zero
nodes, a link to an unknown node, or a duplicate node id.
"""

import argparse
import glob
import json
import random
import os
import shutil
import subprocess
import sys
import tempfile
from xml.sax.saxutils import escape

FONT = "Inter, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"
INK, MUTED, EDGE = "#1f2937", "#4b5563", "#475569"
GROUP_STYLE = {
    "client": ("#eaf4ee", "#7fb592"),
    "gateway": ("#e8eef8", "#8fa6cf"),
    "services": ("#eef0fb", "#8e97d6"),
    "data": ("#fbf3e4", "#d4a85a"),
    "external": ("#f3f4f6", "#9ca3af"),
    "messaging": ("#f5edf8", "#b28fc6"),
}
DASH = {"sync": "", "async": "7 5", "bulk": "2 4"}
KIND_WORDS = {
    "sync": "request and reply",
    "async": "event or message",
    "bulk": "bulk or scheduled data",
}

# Width factors: the average advance of a glyph in em, erring wide so an
# estimated box always holds the real text.
REG, BOLD, CAPS = 0.58, 0.64, 0.74
LANE = 24  # distance between two connections in a gutter
BADGE_R = 10
PAD = 14


def text_w(s, size, factor=REG, spacing=0.0):
    return len(s) * size * factor + max(0, len(s) - 1) * spacing


def wrap(s, size, width, factor=REG):
    """Greedy word wrap into lines no wider than width."""
    words, lines, cur = s.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if cur and text_w(trial, size, factor) > width:
            lines.append(cur)
            cur = w
        else:
            cur = trial
    if cur:
        lines.append(cur)
    return lines or [""]


class Svg:
    def __init__(self):
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def text(
        self,
        x,
        y,
        s,
        size,
        weight=400,
        fill=INK,
        anchor="start",
        factor=REG,
        spacing=0.0,
        within="",
    ):
        """One line of text; data-box is its estimated extent for the gate."""
        w = text_w(s, size, factor, spacing)
        left = x - w / 2 if anchor == "middle" else x
        box = f"{left:.1f} {y - size * 0.8:.1f} {w:.1f} {size * 1.05:.1f}"
        ls = f' letter-spacing="{spacing}"' if spacing else ""
        inside = f' data-in="{escape(within)}"' if within else ""
        self.add(
            f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{ls} data-box="{box}"{inside}>{escape(s)}</text>'
        )


# ---------------------------------------------------------------- the model


def load(path):
    try:
        m = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as e:
        sys.exit(f"render: cannot read {path}: {e}")
    return m


def check_view(view, name):
    ids, problems = set(), []
    for t in view.get("tiers", []):
        for g in t.get("groups", []):
            for n in g.get("nodes", []):
                if n.get("id") in ids:
                    problems.append(f"{name}: duplicate node id '{n.get('id')}'")
                ids.add(n.get("id"))
    for lk in view.get("links", []):
        for end in ("from", "to"):
            if lk.get(end) not in ids:
                problems.append(
                    f"{name}: link {lk.get('from')} -> {lk.get('to')} names unknown node '{lk.get(end)}'"
                )
    return ids, problems


# ---------------------------------------------------------------- measuring


def measure_node(n, inner_w, with_modules):
    """Height of a node box whose inner width is inner_w, and its lines."""
    icon = 26 if n.get("owns_store") or n.get("kind") == "store" else 0
    name_lines = wrap(n.get("name", n["id"]), 14, inner_w - icon, BOLD)
    tech_lines = wrap(n["tech"], 11, inner_w) if n.get("tech") else []
    chips = []
    if with_modules:
        x, row = 0, 0
        for mod in n.get("modules", []):
            cw = min(text_w(mod, 11) + 16, inner_w)
            if x and x + cw > inner_w:
                x, row = 0, row + 1
            chips.append((mod, x, row, cw))
            x += cw + 6
    rows = (chips[-1][2] + 1) if chips else 0
    h = (
        PAD
        + len(name_lines) * 18
        + len(tech_lines) * 14
        + (8 if chips else 0)
        + rows * 28
        + PAD
        - 4
    )
    return max(h, 52), name_lines, tech_lines, chips


def node_width(n, with_modules):
    need = text_w(n.get("name", n["id"]), 14, BOLD) + 2 * PAD + 26
    if with_modules and n.get("modules"):
        widest = max(text_w(m, 11) + 16 for m in n["modules"])
        need = max(need, min(2 * widest + 6, 380) + 2 * PAD)
    return max(180, min(need, 340))


# ---------------------------------------------------------------- routing


def plan_routes(view, tier_of):
    """For each link, the gutters it uses and whether it needs the band.
    Gutter k lies after tier k; gutter -1 lies before tier 0."""
    plans = []
    for idx, lk in enumerate(view.get("links", [])):
        i, j = tier_of[lk["from"]], tier_of[lk["to"]]
        if i == j:
            plans.append(
                {"link": lk, "n": idx + 1, "gutters": [i], "band": False, "dir": 0}
            )
        elif j > i:
            gs = [i] if j == i + 1 else [i, j - 1]
            plans.append(
                {"link": lk, "n": idx + 1, "gutters": gs, "band": j > i + 1, "dir": 1}
            )
        else:
            gs = [i - 1] if i == j + 1 else [i - 1, j]
            plans.append(
                {"link": lk, "n": idx + 1, "gutters": gs, "band": i > j + 1, "dir": -1}
            )
    return plans


# ---------------------------------------------------------------- layout


def layout(view, orientation, with_modules):
    """Place tiers, groups and nodes. Returns rects in (u, v) where u runs
    along the tiers and v across them, plus everything the drawing needs."""
    tiers = view["tiers"]
    tier_of, nodes = {}, {}
    for ti, t in enumerate(tiers):
        for g in t.get("groups", []):
            for n in g.get("nodes", []):
                tier_of[n["id"]] = ti
                nodes[n["id"]] = n
    plans = plan_routes(view, tier_of)
    lanes = {}
    for p in plans:
        for g in p["gutters"]:
            lanes.setdefault(g, []).append(p)
    band = [p for p in plans if p["band"]]
    gutter_w = {k: 36 + LANE * len(lanes.get(k, [])) for k in range(-1, len(tiers))}
    band_h = (LANE * len(band) + 16) if band else 0

    placed = {"nodes": {}, "groups": [], "tiers": []}
    if orientation == "columns":
        title_h = 64
        top = title_h + band_h
        header_h = 40
        x = 24 + gutter_w[-1]
        for ti, t in enumerate(tiers):
            groups = t.get("groups", [])
            nw = max(
                [
                    node_width(n, with_modules)
                    for g in groups
                    for n in g.get("nodes", [])
                ]
                + [180]
            )
            # a title word wider than the group widens the tier: never clipped
            longest = [text_w(w, 13, BOLD) for g in groups for w in g["name"].split()]
            longest += [text_w(w, 12, CAPS, 0.8) - 2 * PAD for w in t["name"].upper().split()]
            nw = max([nw] + longest)
            gw = nw + 2 * PAD
            # a group title wider than the group widens the tier, never spills
            y = top + header_h
            header_lines = wrap(t["name"].upper(), 12, gw, CAPS)
            y += (len(header_lines) - 1) * 16
            gboxes = []
            for g in groups:
                glines = wrap(g["name"], 13, gw - 2 * PAD, BOLD)
                gy, cy = y, y + 14 + len(glines) * 18
                nb = []
                for n in g.get("nodes", []):
                    h, nl, tl, ch = measure_node(n, nw - 2 * PAD, with_modules)
                    nb.append((n, x + PAD, cy, nw, h, nl, tl, ch))
                    cy += h + 14
                gh = cy - gy + 2
                gboxes.append((g, x, gy, gw, gh, glines, nb))
                y = gy + gh + 22
            placed["tiers"].append((t, x, top, gw, header_lines))
            for g, gx, gy, gw_, gh, glines, nb in gboxes:
                placed["groups"].append((g, gx, gy, gw_, gh, glines))
                for n, nx, ny, w, h, nl, tl, ch in nb:
                    placed["nodes"][n["id"]] = (nx, ny, w, h, nl, tl, ch)
            x += gw + gutter_w[ti]
        width = x + 24
        height = (
            max([gy + gh for (_, _, gy, _, gh, _) in placed["groups"]] + [top + 100])
            + 24
        )
    else:  # rows: tiers are horizontal bands stacked top to bottom
        title_h = 56
        left = 24 + band_h  # the band is a vertical strip on the left
        y = title_h + gutter_w[-1]
        maxx = 0
        # Titles sit in a label column on the left of their band and group,
        # never above the nodes, so a line entering a node from above or
        # below crosses no text.
        label_w = 170
        for ti, t in enumerate(tiers):
            header_lines = wrap(t["name"].upper(), 12, label_w - 2 * PAD, CAPS)
            x = left + label_w
            cy0 = y + PAD
            band_bottom = y + PAD + len(header_lines) * 16 + 12
            for g in t.get("groups", []):
                glines = wrap(g["name"], 13, 150, BOLD)
                title_w = max(text_w(s, 13, BOLD) for s in glines)
                gx, cx = x, x + PAD + title_w + PAD
                nb, gh_in = [], 0
                for n in g.get("nodes", []):
                    w = max(160, min(text_w(n.get("name", n["id"]), 14, BOLD) + 2 * PAD + 26, 300))
                    h, nl, tl, ch = measure_node(n, w - 2 * PAD, False)
                    nb.append((n, cx, cy0 + PAD, w, h, nl, tl, ch))
                    gh_in = max(gh_in, h)
                    cx += w + 18
                gw = cx - gx - 18 + PAD
                gh = max(gh_in, len(glines) * 18 + 8) + 2 * PAD
                placed["groups"].append((g, gx, cy0, gw, gh, glines))
                for n, nx, ny, w, h, nl, tl, ch in nb:
                    placed["nodes"][n["id"]] = (nx, ny, w, h, nl, tl, ch)
                x = gx + gw + 24
                band_bottom = max(band_bottom, cy0 + gh)
            bh = band_bottom - y + PAD
            placed["tiers"].append((t, left, y, max(x - left, 200), header_lines, bh))
            maxx = max(maxx, x)
            y += bh + gutter_w[ti]
        width = maxx + 24
        height = y + 8
        for i, (t, tx, ty, tw, hl, bh) in enumerate(placed["tiers"]):
            placed["tiers"][i] = (t, tx, ty, width - 24 - tx, hl, bh)
    return tier_of, plans, lanes, band, band_h, placed, width, height


def route(orientation, plans, lanes, band, band_h, placed, tier_of):
    """Compute each link's polyline. Work in (u, v): u along the tiers."""
    cols = orientation == "columns"

    def uv_rect(nid):
        x, y, w, h = placed["nodes"][nid][:4]
        return (x, x + w, y, y + h) if cols else (y, y + h, x, x + w)

    # the u extent of each tier (its outer edge) and of each gutter
    tier_u = []
    for t in placed["tiers"]:
        if cols:
            _, x, _, w, _ = t
            tier_u.append((x, x + w))
        else:
            _, _, y, _, _, bh = t
            tier_u.append((y, y + bh))
    gutter_u = {}
    for k in range(-1, len(tier_u)):
        lo = (
            tier_u[k][1]
            if k >= 0
            else tier_u[0][0] - (36 + LANE * len(lanes.get(-1, [])))
        )
        hi = (
            tier_u[k + 1][0]
            if k + 1 < len(tier_u)
            else lo + 36 + LANE * len(lanes.get(k, []))
        )
        gutter_u[k] = (lo, hi)

    # ports: spread every link end along the side it uses
    sides = {}
    for p in plans:
        lk = p["link"]
        if p["dir"] >= 0:
            sa = (lk["from"], "hi")
            sb = (lk["to"], "lo" if p["dir"] == 1 else "hi")
        else:
            sa = (lk["from"], "lo")
            sb = (lk["to"], "hi")
        p["sides"] = (sa, sb)
        sides.setdefault(sa, []).append((p, 0))
        sides.setdefault(sb, []).append((p, 1))
    port = {}
    for (nid, side), ends in sides.items():
        u0, u1, v0, v1 = uv_rect(nid)

        def other_v(e):
            p, which = e
            o = p["link"]["to"] if which == 0 else p["link"]["from"]
            r = uv_rect(o)
            return (r[2] + r[3]) / 2

        ends.sort(key=other_v)
        for k, (p, which) in enumerate(ends):
            v = v0 + (v1 - v0) * (k + 1) / (len(ends) + 1)
            port[(p["n"], which)] = (u1 if side == "hi" else u0, v)

    # Lane order decides which runs cross which. The first attempt orders
    # lanes by span; when that leaves two runs on one line, seeded shuffles
    # are tried and the order with the fewest clashes is kept.
    port0, best = dict(port), None
    for attempt in range(16):
        port = dict(port0)
        # lanes: inside each gutter, one u per link, ordered to cut crossings
        lane_u = {}
        for k, ps in lanes.items():
            lo, hi = gutter_u[k]
            ps = sorted(
                ps, key=lambda p: (abs(port[(p["n"], 0)][1] - port[(p["n"], 1)][1]), p["n"])
            )
            if attempt:
                random.Random(attempt * 7919 + k).shuffle(ps)
            for idx, p in enumerate(ps):
                lane_u[(p["n"], k)] = lo + 18 + LANE * idx + LANE / 2
        band_v = {}
        for idx, p in enumerate(sorted(band, key=lambda p: p["n"])):
            band_v[p["n"]] = (64 if cols else 24) + 8 + LANE * idx

        def build():
            out = []
            for p in plans:
                (ua, va), (ub, vb) = port[(p["n"], 0)], port[(p["n"], 1)]
                g = p["gutters"]
                if len(g) == 1:
                    lu = lane_u[(p["n"], g[0])]
                    pts = [(ua, va), (lu, va), (lu, vb), (ub, vb)]
                else:
                    l1, l2 = lane_u[(p["n"], g[0])], lane_u[(p["n"], g[1])]
                    bv = band_v[p["n"]]
                    pts = [(ua, va), (l1, va), (l1, bv), (l2, bv), (l2, vb), (ub, vb)]
                p["uv"] = pts
                p["badge_lane"] = (
                    lane_u[(p["n"], g[0])],
                    min(pts[1][1], pts[2][1]),
                    max(pts[1][1], pts[2][1]),
                )
                out.append(p)
            return out

        # Two runs from a node side to a lane that sit within a few pixels of
        # each other read as one line. Move one of the two ports along its side
        # until every pair of overlapping runs is clear; a clash no move can fix
        # is left for diagram_check.py to report.
        def end_runs(p):
            return [(0, p["uv"][0], p["uv"][1]), (1, p["uv"][-2], p["uv"][-1])]

        def clashes(paths, skip):
            for i, p in enumerate(paths):
                for q in paths[i + 1:]:
                    for owner, other in ((q, p), (p, q)):
                        for end, s0, s1 in end_runs(owner):
                            for r0, r1 in zip(other["uv"], other["uv"][1:]):
                                if abs(r0[1] - r1[1]) > 0.1 or abs(r0[1] - s0[1]) >= 6:
                                    continue
                                lo = max(min(r0[0], r1[0]), min(s0[0], s1[0]))
                                hi = min(max(r0[0], r1[0]), max(s0[0], s1[0]))
                                if hi - lo > 2 and (owner["n"], end) not in skip:
                                    return owner, end
            return None

        skip, moves = set(), {}
        for _ in range(400):
            paths = build()
            c = clashes(paths, skip)
            if not c:
                break
            q, end_q = c
            key = (q["n"], end_q)
            nid = q["link"]["from"] if end_q == 0 else q["link"]["to"]
            u0, u1, v0, v1 = uv_rect(nid)
            u, v = port[key]
            taken = [pv for k2, (pu, pv) in port.items() if k2 != key and abs(pu - u) < 0.5]
            moved = False
            for off in (8, -8, 16, -16, 24, -24, 32, -32):
                nv = v + off
                if v0 + 4 < nv < v1 - 4 and all(abs(nv - o) >= 6 for o in taken):
                    port[key] = (u, nv)
                    moved = True
                    break
            moves[key] = moves.get(key, 0) + 1
            if not moved or moves[key] > 6:
                skip.add(key)

        left = 0
        seen = set()
        while True:
            c = clashes(paths, seen)
            if not c:
                break
            seen.add((c[0]["n"], c[1]))
            left += 1
        if best is None or left < best[0]:
            best = (left, dict(port), dict(lane_u))
        if left == 0:
            break
    port, lane_u = best[1], best[2]
    paths = build()

    # badges: on the link's own lane, away from other links' crossings
    for p in paths:
        lu, a, b = p["badge_lane"]
        others = []
        for q in paths:
            if q is p:
                continue
            for (u1, v1), (u2, v2) in zip(q["uv"], q["uv"][1:]):
                if v1 == v2 and min(u1, u2) - 1 <= lu <= max(u1, u2) + 1:
                    others.append(v1)
        mid = (a + b) / 2
        best = mid
        for step in range(0, 400, 3):
            cands = [mid + step, mid - step] if step else [mid]
            ok = [
                c
                for c in cands
                if a - 1 <= c <= b + 1 and all(abs(c - o) > BADGE_R + 3 for o in others)
            ]
            if ok:
                best = ok[0]
                break
        p["badge_uv"] = (lu, best)

    def xy(pt):
        return pt if cols else (pt[1], pt[0])

    for p in paths:
        p["pts"] = [xy(pt) for pt in p["uv"]]
        p["badge"] = xy(p["badge_uv"])
    return paths


# ---------------------------------------------------------------- drawing


def cylinder(svg, x, y):
    svg.add(
        f'<g data-icon="store"><path d="M{x} {y + 4} v12 a9 4 0 0 0 18 0 v-12" fill="#dbeafe" stroke="#3b6fb6" stroke-width="1.2"/>'
        f'<ellipse cx="{x + 9}" cy="{y + 4}" rx="9" ry="4" fill="#eff6ff" stroke="#3b6fb6" stroke-width="1.2"/></g>'
    )


def draw(title, view, orientation, with_modules):
    tier_of, plans, lanes, band, band_h, placed, W, H = layout(
        view, orientation, with_modules
    )
    paths = route(orientation, plans, lanes, band, band_h, placed, tier_of)
    names = {
        nid: n.get("name", nid)
        for t in view["tiers"]
        for g in t.get("groups", [])
        for n in g.get("nodes", [])
        for nid in [n["id"]]
    }

    # legend below the drawing
    legend_top = H + 8
    col_w = (W - 48) / 2 if len(paths) > 8 else W - 48
    per_col = (len(paths) + 1) // 2 if len(paths) > 8 else len(paths)
    rows = []
    for k, p in enumerate(paths):
        lk = p["link"]
        head = f"{names[lk['from']]} to {names[lk['to']]}"
        kind = KIND_WORDS.get(lk.get("kind", "sync"), "request and reply")
        if lk.get("unconfirmed"):
            kind += ", unconfirmed: no call site found"
        body = f"{lk.get('label', '')} ({kind})"
        lines = wrap(head + ": " + body, 12, col_w - 40)
        rows.append((p, lines))
    col_heights, y_in_col = [0, 0], []
    for k, (p, lines) in enumerate(rows):
        c = 0 if k < per_col else 1
        y_in_col.append((c, col_heights[c]))
        col_heights[c] += len(lines) * 16 + 8
    legend_h = 40 + max(col_heights) + 60
    H2 = legend_top + legend_h

    svg = Svg()
    svg.add(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H2:.0f}" viewBox="0 0 {W:.0f} {H2:.0f}" '
        f'font-family="{FONT}" data-view="{orientation}">'
    )
    svg.add(f'<rect x="0" y="0" width="{W:.0f}" height="{H2:.0f}" fill="#ffffff"/>')
    svg.text(24, 36, title, 20, 700)

    for t in placed["tiers"]:
        if orientation == "columns":
            tt, x, top, w, hl = t
            for i, line in enumerate(hl):
                svg.text(
                    x, top + 26 + i * 16, line, 12, 600, MUTED, factor=CAPS, spacing=0.8
                )
        else:
            tt, x, y, w, hl, bh = t
            svg.add(
                f'<rect x="{x}" y="{y}" width="{w:.1f}" height="{bh:.1f}" rx="12" fill="#f8fafc" stroke="#cbd5e1" data-tier="{escape(tt["name"])}"/>'
            )
            for i, line in enumerate(hl):
                svg.text(x + PAD, y + 26 + i * 16, line, 12, 600, MUTED, factor=CAPS, spacing=0.8)

    for gi, (g, gx, gy, gw, gh, glines) in enumerate(placed["groups"]):
        fill, stroke = GROUP_STYLE.get(
            g.get("kind", "services"), GROUP_STYLE["services"]
        )
        dash = ' stroke-dasharray="6 4"' if g.get("kind") == "external" else ""
        svg.add(
            f'<rect x="{gx:.1f}" y="{gy:.1f}" width="{gw:.1f}" height="{gh:.1f}" rx="12" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="1.4"{dash} data-group="{gi}"/>'
        )
        for i, line in enumerate(glines):
            if orientation == "columns":
                tx, ty, anchor = gx + gw / 2, gy + 24 + i * 18, "middle"
            else:
                tx, ty, anchor = gx + PAD, gy + PAD + 16 + i * 18, "start"
            svg.text(tx, ty, line, 13, 700, "#374151", anchor, BOLD, within=f"group:{gi}")

    for nid, (x, y, w, h, nl, tl, ch) in placed["nodes"].items():
        n = [
            n
            for t in view["tiers"]
            for g in t.get("groups", [])
            for n in g.get("nodes", [])
            if n["id"] == nid
        ][0]
        ext = n.get("kind") == "external"
        fill = "#e6efff" if n.get("kind") == "store" else "#ffffff"
        stroke = "#6b7280" if ext else "#5b6b8c"
        dash = ' stroke-dasharray="5 4"' if ext else ""
        svg.add(
            f'<g data-node="{escape(nid)}"><rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="8" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="1.4"{dash}/>'
        )
        cy = y + PAD + 12
        for line in nl:
            svg.text(
                x + w / 2, cy, line, 14, 700, INK, "middle", BOLD, within="node:" + nid
            )
            cy += 18
        for line in tl:
            svg.text(
                x + w / 2, cy - 2, line, 11, 400, MUTED, "middle", within="node:" + nid
            )
            cy += 14
        if n.get("owns_store") or n.get("kind") == "store":
            cylinder(svg, x + w - 28, y + 8)
        if ch:
            inner = w - 2 * PAD
            rows_w = {}
            for m, mx, row, cw in ch:
                rows_w[row] = mx + cw
            base = cy + 4
            for m, mx, row, cw in ch:
                off = (inner - rows_w[row]) / 2
                cx0, cy0 = x + PAD + off + mx, base + row * 28
                svg.add(
                    f'<rect x="{cx0:.1f}" y="{cy0:.1f}" width="{cw:.1f}" height="22" rx="5" fill="#ffffff" stroke="#b6c2dc" data-module="{escape(m)}"/>'
                )
                svg.text(
                    cx0 + cw / 2,
                    cy0 + 15,
                    m,
                    11,
                    400,
                    "#334155",
                    "middle",
                    within="node:" + nid,
                )
        svg.add("</g>")

    svg.add(
        f'<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
        f'<path d="M0 0 L10 5 L0 10 z" fill="{EDGE}"/></marker></defs>'
    )
    for p in paths:
        lk = p["link"]
        d = " ".join(
            ("M" if i == 0 else "L") + f"{x:.1f} {y:.1f}"
            for i, (x, y) in enumerate(p["pts"])
        )
        dash = DASH.get(lk.get("kind", "sync"), "")
        da = f' stroke-dasharray="{dash}"' if dash else ""
        colour = "#94a3b8" if lk.get("unconfirmed") else EDGE
        svg.add(
            f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="1.4"{da} marker-end="url(#arrow)" '
            f'data-edge="{p["n"]}" data-from="{escape(lk["from"])}" data-to="{escape(lk["to"])}"/>'
        )
    for p in paths:
        bx, by = p["badge"]
        svg.add(
            f'<g data-badge="{p["n"]}" data-box="{bx - BADGE_R:.1f} {by - BADGE_R:.1f} {2 * BADGE_R} {2 * BADGE_R}">'
            f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="{BADGE_R}" fill="#ffffff" stroke="{EDGE}" stroke-width="1.3"/>'
            f'<text x="{bx:.1f}" y="{by + 4:.1f}" font-size="11" font-weight="700" fill="{INK}" text-anchor="middle">{p["n"]}</text></g>'
        )

    # legend
    svg.add(
        f'<line x1="24" y1="{legend_top:.1f}" x2="{W - 24:.1f}" y2="{legend_top:.1f}" stroke="#e5e7eb"/>'
    )
    svg.text(
        24,
        legend_top + 26,
        "WHAT EACH CONNECTION CARRIES",
        12,
        600,
        MUTED,
        factor=CAPS,
        spacing=0.8,
    )
    for k, (p, lines) in enumerate(rows):
        c, off = y_in_col[k]
        lx, ly = 24 + c * col_w, legend_top + 52 + off
        svg.add(
            f'<g data-legend="{p["n"]}"><circle cx="{lx + 10}" cy="{ly - 4}" r="9" fill="#ffffff" stroke="{EDGE}"/>'
            f'<text x="{lx + 10}" y="{ly}" font-size="10" font-weight="700" fill="{INK}" text-anchor="middle">{p["n"]}</text></g>'
        )
        for i, line in enumerate(lines):
            svg.text(lx + 28, ly + i * 16, line, 12, 400, INK)
    ky = legend_top + 40 + max(col_heights) + 28
    kx = 24
    for kind, word in KIND_WORDS.items():
        dash = DASH[kind]
        da = f' stroke-dasharray="{dash}"' if dash else ""
        svg.add(
            f'<line x1="{kx}" y1="{ky - 4}" x2="{kx + 34}" y2="{ky - 4}" stroke="{EDGE}" stroke-width="1.4"{da}/>'
        )
        svg.text(kx + 42, ky, word, 11, 400, MUTED)
        kx += 42 + text_w(word, 11) + 28
    note = "a box inside a service is a module; the cylinder marks a service that owns its data; a dashed box is outside our control"
    svg.text(kx, ky, note, 11, 400, MUTED)
    W2 = max(W, kx + text_w(note, 11) + 24)
    svg.add("</svg>")
    out = "\n".join(svg.parts)
    if W2 > W:
        out = out.replace(
            f'width="{W:.0f}" height="{H2:.0f}" viewBox="0 0 {W:.0f} {H2:.0f}"',
            f'width="{W2:.0f}" height="{H2:.0f}" viewBox="0 0 {W2:.0f} {H2:.0f}"',
            1,
        )
        out = out.replace(
            f'<rect x="0" y="0" width="{W:.0f}" height="{H2:.0f}"',
            f'<rect x="0" y="0" width="{W2:.0f}" height="{H2:.0f}"',
            1,
        )
    return out, W2, H2


# ---------------------------------------------------------------- PNG


def chrome():
    for c in (
        os.environ.get("CHROME_PATH"),
        shutil.which("google-chrome"),
        shutil.which("chromium"),
        shutil.which("chromium-browser"),
        shutil.which("chrome"),
    ):
        if c and os.path.exists(c):
            return c
    base = os.environ.get(
        "PLAYWRIGHT_BROWSERS_PATH", os.path.expanduser("~/.cache/ms-playwright")
    )
    found = sorted(
        glob.glob(os.path.join(base, "chromium-*", "chrome-linux*", "chrome"))
        + glob.glob(
            os.path.join(
                base,
                "chromium-*",
                "chrome-mac*",
                "Chromium.app",
                "Contents",
                "MacOS",
                "Chromium",
            )
        )
    )
    return found[-1] if found else None


def to_png(svg_path, png_path, w, h):
    c = chrome()
    if not c:
        return "no Chrome or Chromium found (set CHROME_PATH)"
    with tempfile.TemporaryDirectory() as d:
        page = os.path.join(d, "page.html")
        with open(page, "w", encoding="utf-8") as f:
            f.write(
                '<!doctype html><html><body style="margin:0;background:#fff">'
                + open(svg_path, encoding="utf-8").read()
                + "</body></html>"
            )
        cmd = [
            c,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            "--force-device-scale-factor=2",
            f"--window-size={int(w)},{int(h)}",
            f"--user-data-dir={d}/profile",
            f"--screenshot={os.path.abspath(png_path)}",
            "file://" + page,
        ]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if r.returncode != 0 or not os.path.exists(png_path):
            return (
                "Chrome failed: " + (r.stderr.strip().splitlines() or ["no output"])[-1]
            )
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="docs/architecture/architecture.json")
    ap.add_argument("--out", default="docs/architecture/diagrams")
    ap.add_argument("--no-png", action="store_true")
    a = ap.parse_args()
    m = load(a.model)
    project = "".join(
        w[:1].upper() + w[1:]
        for w in str(m.get("project", "Project")).replace("-", " ").split()
    )
    version = int(m.get("version", 1))
    views = []
    if m.get("system_diagram"):
        views.append(
            (
                "SystemArchitecture",
                "System Architecture",
                m["system_diagram"],
                "columns",
                True,
            )
        )
        views.append(
            (
                "ArchitectureFlow",
                "Architecture Flow",
                m["system_diagram"],
                "rows",
                False,
            )
        )
    if m.get("deployment_diagram"):
        views.append(
            (
                "DeploymentArchitecture",
                "Deployment Architecture",
                m["deployment_diagram"],
                "columns",
                True,
            )
        )
    problems, nodes_total, links_total = [], 0, 0
    for stem, _, view, _, _ in views:
        ids, pr = check_view(view, stem)
        problems += pr
        if stem != "ArchitectureFlow":
            nodes_total += len(ids)
            links_total += len(view.get("links", []))
    if problems or nodes_total == 0:
        for p in problems:
            print(f"problem: {p}")
        if nodes_total == 0:
            print(
                f"render: 0 nodes in {a.model} (system_diagram, deployment_diagram), nothing drawn",
                file=sys.stderr,
            )
        return 1
    os.makedirs(a.out, exist_ok=True)
    written, pngs, png_note = 0, 0, ""
    for stem, label, view, orient, mods in views:
        svg, w, h = draw(f"{project}: {label}", view, orient, mods)
        name = f"{project}_{stem}_v{version}"
        path = os.path.join(a.out, name + ".svg")
        with open(path, "w", encoding="utf-8") as f:
            f.write(svg)
        written += 1
        print(f"render: {path} ({w:.0f}x{h:.0f})")
        if not a.no_png:
            err = to_png(path, os.path.join(a.out, name + ".png"), w, h)
            if err:
                png_note = err
            else:
                pngs += 1
                print(f"render: {os.path.join(a.out, name + '.png')}")
    tail = f", {pngs} PNG" if not a.no_png else ", PNG not requested"
    if png_note and not pngs:
        tail = f", PNG not written ({png_note})"
    print(
        f"render: {written} views, {nodes_total} nodes, {links_total} connections{tail}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
