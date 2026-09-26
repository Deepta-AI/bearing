#!/usr/bin/env python3
"""diagram_check: a rendered architecture diagram is legible, proved from the
SVG and the model, not from the renderer's word.

For each SVG (render.py marks what it drew with data- attributes):
  - Completeness: every node in the model is drawn (data-node), every link is
    drawn (data-edge) with its badge (data-badge) and a legend row
    (data-legend). The flow view is checked against the system model.
  - No overlap: no two pieces of text (data-box, badges included) overlap.
  - No clipping: text marked data-in="node:<id>" or "group:<name>" lies
    inside that node's or group's rectangle, and all text lies inside the
    canvas.
  - No line through a box: no segment of a connection crosses a node other
    than its own two ends, and no segment crosses any text.
  - No shared line: no two connections run along the same stretch.
  - The file name carries the version: <Project>_<View>_v<N>.svg.

Usage: diagram_check.py [--model docs/architecture/architecture.json]
                        [--dir docs/architecture/diagrams]
Prints one line per problem and a counts line; exits 1 on any problem, or
when zero diagrams or zero nodes were checked.
"""

import argparse
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

NS = "{http://www.w3.org/2000/svg}"
EPS = 0.5


def box(s):
    x, y, w, h = (float(v) for v in s.split())
    return (x, y, x + w, y + h)


def overlap(a, b, pad=0.0):
    return (
        a[0] < b[2] - pad
        and b[0] < a[2] - pad
        and a[1] < b[3] - pad
        and b[1] < a[3] - pad
    )


def inside(a, b):
    return (
        a[0] >= b[0] - EPS
        and a[1] >= b[1] - EPS
        and a[2] <= b[2] + EPS
        and a[3] <= b[3] + EPS
    )


def seg_hits(p, q, r, shrink=1.0):
    """Does the axis-parallel segment p-q pass through the inside of r?"""
    x0, y0, x1, y1 = r[0] + shrink, r[1] + shrink, r[2] - shrink, r[3] - shrink
    if abs(p[1] - q[1]) < EPS:  # horizontal
        y = p[1]
        return y0 < y < y1 and min(p[0], q[0]) < x1 and max(p[0], q[0]) > x0
    if abs(p[0] - q[0]) < EPS:  # vertical
        x = p[0]
        return x0 < x < x1 and min(p[1], q[1]) < y1 and max(p[1], q[1]) > y0
    return overlap(
        (min(p[0], q[0]), min(p[1], q[1]), max(p[0], q[0]), max(p[1], q[1])), r
    )


def rect_of(el):
    x, y = float(el.get("x")), float(el.get("y"))
    return (x, y, x + float(el.get("width")), y + float(el.get("height")))


def points(d):
    nums = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", d)]
    return list(zip(nums[0::2], nums[1::2]))


def model_view(model, stem):
    if stem.startswith("DeploymentArchitecture"):
        return model.get("deployment_diagram")
    return model.get("system_diagram")


def check(path, model):
    problems = []
    name = os.path.basename(path)
    m = re.match(r"^[A-Z][A-Za-z0-9]*_([A-Za-z]+)_v(\d+)\.svg$", name)
    if not m:
        return [f"{name}: file name is not <Project>_<View>_v<N>.svg"], 0, 0, 0
    view = model_view(model, m.group(1))
    if not view:
        return [f"{name}: the model has no view for {m.group(1)}"], 0, 0, 0
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        return [f"{name}: not valid SVG ({e})"], 0, 0, 0
    canvas = (0.0, 0.0, float(root.get("width")), float(root.get("height")))

    want_nodes = {
        n["id"]
        for t in view.get("tiers", [])
        for g in t.get("groups", [])
        for n in g.get("nodes", [])
    }
    want_links = len(view.get("links", []))
    nodes, groups, texts, edges, badges, legend = {}, {}, [], [], [], set()
    for el in root.iter():
        tag = el.tag.replace(NS, "")
        if tag == "g" and el.get("data-node") is not None:
            r = el.find(NS + "rect")
            nodes[el.get("data-node")] = rect_of(r)
        elif tag == "rect" and el.get("data-group") is not None:
            groups[el.get("data-group")] = rect_of(el)
        elif tag == "text" and el.get("data-box"):
            texts.append(
                (box(el.get("data-box")), el.get("data-in", ""), (el.text or "")[:40])
            )
        elif tag == "path" and el.get("data-edge"):
            edges.append(
                (
                    el.get("data-edge"),
                    el.get("data-from"),
                    el.get("data-to"),
                    points(el.get("d")),
                )
            )
        elif tag == "g" and el.get("data-badge"):
            badges.append(
                (box(el.get("data-box")), "", "badge " + el.get("data-badge"))
            )
        elif tag == "g" and el.get("data-legend"):
            legend.add(el.get("data-legend"))

    for nid in sorted(want_nodes - set(nodes)):
        problems.append(f"{name}: node '{nid}' is in the model but not drawn")
    if len(edges) != want_links:
        problems.append(
            f"{name}: {len(edges)} connections drawn, the model has {want_links}"
        )
    if len(badges) != len(edges):
        problems.append(f"{name}: {len(badges)} badges for {len(edges)} connections")
    missing_legend = {e[0] for e in edges} - legend
    for n in sorted(missing_legend, key=int):
        problems.append(f"{name}: connection {n} has no legend row")

    allt = texts + badges
    for i in range(len(allt)):
        a = allt[i]
        if not inside(a[0], canvas):
            problems.append(f"{name}: text '{a[2]}' runs off the canvas")
        for j in range(i + 1, len(allt)):
            b = allt[j]
            if overlap(a[0], b[0], 0.5):
                problems.append(f"{name}: '{a[2]}' overlaps '{b[2]}'")
    for bx, within, label in texts:
        if not within:
            continue
        kind, _, key = within.partition(":")
        r = nodes.get(key) if kind == "node" else groups.get(key)
        if r is None:
            problems.append(f"{name}: text '{label}' belongs to unknown {kind} '{key}'")
        elif not inside(bx, r):
            problems.append(f"{name}: text '{label}' is clipped by its {kind} '{key}'")

    crossings = 0
    for n, a, b, pts in edges:
        for p, q in zip(pts, pts[1:]):
            for nid, r in nodes.items():
                if nid in (a, b):
                    continue
                if seg_hits(p, q, r):
                    crossings += 1
                    problems.append(
                        f"{name}: connection {n} ({a} to {b}) passes through node '{nid}'"
                    )
            for bx, _, label in texts:
                if seg_hits(p, q, bx, 0.0):
                    crossings += 1
                    problems.append(
                        f"{name}: connection {n} ({a} to {b}) crosses the text '{label}'"
                    )
    # two connections drawn along the same stretch of line cannot be told apart
    segs = []
    for (n, a, b, pts) in edges:
        for p, q in zip(pts, pts[1:]):
            segs.append((n, p, q))
    for i in range(len(segs)):
        n1, p1, q1 = segs[i]
        for j in range(i + 1, len(segs)):
            n2, p2, q2 = segs[j]
            if n1 == n2:
                continue
            if abs(p1[1] - q1[1]) < EPS and abs(p2[1] - q2[1]) < EPS and abs(p1[1] - p2[1]) < 2:
                lo = max(min(p1[0], q1[0]), min(p2[0], q2[0]))
                hi = min(max(p1[0], q1[0]), max(p2[0], q2[0]))
            elif abs(p1[0] - q1[0]) < EPS and abs(p2[0] - q2[0]) < EPS and abs(p1[0] - p2[0]) < 2:
                lo = max(min(p1[1], q1[1]), min(p2[1], q2[1]))
                hi = min(max(p1[1], q1[1]), max(p2[1], q2[1]))
            else:
                continue
            if hi - lo > 2:
                problems.append(f"{name}: connections {n1} and {n2} share {hi - lo:.0f}px of line")
    return problems, len(nodes), len(edges), len(allt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="docs/architecture/architecture.json")
    ap.add_argument("--dir", default="docs/architecture/diagrams")
    a = ap.parse_args()
    try:
        model = json.load(open(a.model, encoding="utf-8"))
    except (OSError, ValueError) as e:
        print(f"diagram-check: cannot read {a.model}: {e}", file=sys.stderr)
        return 1
    files = sorted(glob.glob(os.path.join(a.dir, "*.svg")))
    if not files:
        print(
            f"diagram-check: 0 SVG files in {a.dir}, nothing checked", file=sys.stderr
        )
        return 1
    problems, n_nodes, n_edges, n_text = [], 0, 0, 0
    for f in files:
        p, nn, ne, nt = check(f, model)
        problems += p
        n_nodes, n_edges, n_text = n_nodes + nn, n_edges + ne, n_text + nt
    for p in problems:
        print(f"problem: {p}")
    print(
        f"diagram-check: {len(files)} diagrams, {n_nodes} nodes, {n_edges} connections, "
        f"{n_text} text boxes, {len(problems)} problems"
    )
    if n_nodes == 0:
        print("diagram-check: 0 nodes drawn, nothing checked", file=sys.stderr)
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
