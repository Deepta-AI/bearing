#!/usr/bin/env python3
"""threats_check: every threat in a threat model has a well-formed unique id
and a mitigation that can be checked, and a sensitive scope has threats,
computed from the files.

  - Files: docs/security/threat-model-*.md, or the paths given.
  - Sensitive classes: the value of the "Sensitive classes:" line in the
    scope section; any of auth, payments, PII, external input counts, and
    "none" alone means none.
  - Threats: the rows of the table under the "Threats" heading. The first
    cell is the id and must read T-nn (two or three digits); a duplicate id
    in one file is a problem. A row whose text says "considered, none" is a
    skipped category, not a threat.
  - Mitigation (the column headed Mitigation) must hold one of: a
    path:line whose file exists under --root and has that many lines; a
    story id US-nn-nnn that is a heading in the backlog; or "new story:"
    with a title. "handled by the framework" (or "the framework handles")
    is a problem whatever else the cell says, and so is an empty cell.
  - A file whose scope names a sensitive class and holds zero threats is a
    problem.

Usage: threats_check.py [files...] [--backlog B] [--root R]
Prints one "problem:" line per failure, the counts and the gate line; exits
1 on any problem, or when zero files or zero threats were read.
"""

import argparse
import glob
import os
import re
import sys

SENSITIVE = ("auth", "payments", "pii", "external input")
ID_RE = re.compile(r"^T-\d{2,3}$")
PATH_LINE = re.compile(r"([A-Za-z0-9_./-]+\.[A-Za-z0-9]+):(\d+)")
FRAMEWORK = re.compile(
    r"handled by the framework|the framework handles|framework handles it", re.I
)


def read(p):
    return (
        open(p, encoding="utf-8", errors="replace").read()
        if p and os.path.isfile(p)
        else None
    )


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def threat_table(text):
    """(header, rows) of the first table after a heading that names Threats."""
    m = re.search(r"^#{2,4}\s+(?:\d+\.\s*)?Threats\b.*$", text, re.M)
    if not m:
        return [], []
    header, rows = [], []
    for line in text[m.end() :].split("\n"):
        if re.match(r"^#{1,4}\s", line):
            break
        if not line.startswith("|"):
            if header and rows and line.strip():
                break
            continue
        c = cells(line)
        if not header:
            header = [h.lower() for h in c]
            continue
        if all(re.match(r"^:?-+:?$", x) for x in c if x):
            continue
        rows.append(c)
    return header, rows


def sensitive_classes(text):
    m = re.search(r"Sensitive classes:\s*(.*)$", text, re.M)
    if not m:
        return None
    val = m.group(1).lower()
    return [s for s in SENSITIVE if s in val]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--backlog", default="docs/product/backlog.md")
    ap.add_argument("--root", default=".")
    a = ap.parse_args()

    files = a.files or sorted(glob.glob("docs/security/threat-model-*.md"))
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        print(
            "threat-model: 0 threat models read (docs/security/threat-model-*.md), nothing checked",
            file=sys.stderr,
        )
        return 1
    backlog = read(a.backlog)
    stories = set(re.findall(r"^#{2,4}\s+(US-\d{2}-\d{3})\b", backlog or "", re.M))

    problems = []
    n_threats = n_code = n_story = n_new = n_sensitive = n_retired = 0
    status = {"mitigated": 0, "planned": 0, "unmitigated": 0}
    cats = {k: 0 for k in "STRIDE"}
    for f in files:
        text = read(f)
        classes = sensitive_classes(text)
        if classes is None:
            problems.append(f"{f}: no 'Sensitive classes:' line in the scope section")
            classes = []
        n_sensitive += len(classes)
        header, rows = threat_table(text)
        if not header:
            problems.append(f"{f}: no Threats table")
        col = {name: i for i, name in enumerate(header)}
        mi = col.get("mitigation")
        si = col.get("status")
        ci = col.get("category")
        if header and mi is None:
            problems.append(f"{f}: the Threats table has no Mitigation column")
        seen, count = set(), 0
        for r in rows:
            tid = r[0] if r else ""
            if "considered, none" in " ".join(r).lower():
                continue
            count += 1
            if not ID_RE.match(tid):
                problems.append(f"{f}: threat id '{tid}' is not of the form T-nn")
            elif tid in seen:
                problems.append(f"{f}: duplicate threat id {tid}")
            seen.add(tid)
            cat = r[ci].strip()[:1].upper() if ci is not None and ci < len(r) else ""
            if cat in cats:
                cats[cat] += 1
            st = r[si].lower() if si is not None and si < len(r) else ""
            if st.startswith("retired"):
                # A revision retires a threat instead of deleting it, so the
                # id vapt-report cites stays; it needs the version and a reason.
                count -= 1
                n_retired += 1
                if cat in cats:
                    cats[cat] -= 1
                if not re.match(r"retired in v\d+\s*[:,(-]\s*\S", st):
                    problems.append(
                        f"{f}: {tid} is retired without 'retired in v<n>: <reason>'"
                    )
                continue
            for k in status:
                if st.startswith(k):
                    status[k] += 1
            if mi is None:
                continue
            mit = r[mi] if mi < len(r) else ""
            if not mit:
                problems.append(f"{f}: {tid} has no mitigation")
                continue
            if FRAMEWORK.search(mit):
                problems.append(
                    f"{f}: {tid} mitigation '{mit}' is not a mitigation; name the file and line or make it a story"
                )
                continue
            ok = False
            for path, line in PATH_LINE.findall(mit):
                full = os.path.join(a.root, path)
                if not os.path.isfile(full):
                    problems.append(
                        f"{f}: {tid} cites {path}:{line}, which does not exist"
                    )
                elif sum(
                    1 for _ in open(full, encoding="utf-8", errors="replace")
                ) < int(line):
                    problems.append(
                        f"{f}: {tid} cites {path}:{line}, past the end of the file"
                    )
                else:
                    ok = True
                    n_code += 1
            for us in re.findall(r"\bUS-\d{2}-\d{3}\b", mit):
                if us in stories:
                    ok = True
                    n_story += 1
                else:
                    problems.append(
                        f"{f}: {tid} cites {us}, which is not a story in {a.backlog}"
                    )
            if re.search(r"new story:\s*\S", mit, re.I):
                ok = True
                n_new += 1
            if (
                not ok
                and not PATH_LINE.search(mit)
                and not re.search(r"\bUS-\d{2}-\d{3}\b", mit)
            ):
                problems.append(
                    f"{f}: {tid} mitigation '{mit}' is not a path:line, a story id or 'new story:'"
                )
        n_threats += count
        if classes and count == 0:
            problems.append(
                f"{f}: sensitive scope ({', '.join(classes)}) with 0 threats"
            )

    if n_threats == 0 and not problems:
        print(
            f"threat-model: {len(files)} files, 0 threats read, nothing checked",
            file=sys.stderr,
        )
        return 1
    for p in problems:
        print(f"problem: {p}")
    print(
        f"threat-model: {len(files)} files, {n_threats} threats (mitigated {status['mitigated']}, "
        f"planned {status['planned']}, unmitigated {status['unmitigated']}; retired {n_retired}), mitigations: code {n_code}, "
        f"story {n_story}, new story {n_new}; {n_sensitive} sensitive classes, {len(problems)} problems"
    )
    print("Threats by category: " + ", ".join(f"{k} {v}" for k, v in cats.items()))
    zero = any("with 0 threats" in p for p in problems)
    print(
        f"Gate: {'passed' if not problems else ('FAILED (sensitive scope, 0 threats)' if zero else f'FAILED ({len(problems)} problems)')}"
    )
    return 1 if problems or n_threats == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
