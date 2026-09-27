#!/usr/bin/env python3
"""collect_findings: the scanner findings a VAPT report is written from.

Sources, newest report of each, read from the repository root:
  - claude-security: CLAUDE-SECURITY-<ts>/CLAUDE-SECURITY-RESULTS.jsonl with
    its CLAUDE-SECURITY-REVISION-<sha>.json stamp (the scanned commit and the
    verification status the renderer derived from the vote record);
  - gstack /cso: .gstack/security-reports/<date>-<time>.json.

Findings at the same file and line are merged into one row: the higher
severity wins and both sources are named. Rows from different sources in the
same file and area at different lines are NOT merged (a scanner may report
the route, another the sink); each pair is printed as "check: possible
duplicate" for the writer to resolve by reading the code.

A claude-security scan of another commit than --commit is stale. A /cso
report dated before --commit-time (the release commit's time) did not see
every commit of the release and is stale; without --commit-time, before
--since. A stale source fails unless --allow-stale is given (the report then
says so). Each source's coverage (claude-security's stamp scope and base,
/cso's mode and scope) is printed on a "coverage:" line, so a diff-scoped
scan is never read as whole-repository coverage.

Writes the merged rows as JSON to --out, and a .gitignore of "*" beside it
when that folder has none (scanner rows can quote secret values). Prints the
counts. Exits 1 when no scanner report is found ("run /cso or claude-security
first"), when a source is stale without --allow-stale, or when a report
cannot be read.

Usage: collect_findings.py [--root .] [--commit SHA] [--commit-time ISO-8601]
                           [--since ISO-8601] [--allow-stale]
                           [--out .scratch/vapt-findings.json]
"""

import argparse
import glob
import json
import os
import sys
from datetime import datetime, timezone

RANK = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "INFO": 0}
NAME = {4: "Critical", 3: "High", 2: "Medium", 1: "Low", 0: "Info"}


def newest(pattern):
    hits = sorted(glob.glob(pattern))
    return hits[-1] if hits else None


def parse_time(s):
    try:
        t = datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=timezone.utc)


def claude_security(root, commit, problems):
    results = newest(
        os.path.join(root, "CLAUDE-SECURITY-*", "CLAUDE-SECURITY-RESULTS.jsonl")
    )
    if not results:
        return None, []
    d = os.path.dirname(results)
    stamp_path = newest(os.path.join(d, "CLAUDE-SECURITY-REVISION-*.json"))
    stamp = json.load(open(stamp_path, encoding="utf-8")) if stamp_path else {}
    rev = stamp.get("revision") or {}
    scanned = rev.get("commit") or rev.get("head") or ""
    status = (stamp.get("verification") or {}).get("status", "no stamp")
    src = {
        "name": "claude-security",
        "report": os.path.relpath(results, root),
        "commit": scanned[:12],
        "verification": status,
        "scope": rev.get("scope", "unknown"),
        "base": rev.get("base", ""),
        "stale": bool(
            commit
            and scanned
            and not scanned.startswith(commit[:12])
            and not commit.startswith(scanned[:12])
        ),
    }
    if not stamp_path:
        problems.append(
            f"claude-security: no revision stamp beside {src['report']}; the scanned commit is unknown"
        )
    rows = []
    for n, line in enumerate(open(results, encoding="utf-8"), 1):
        if not line.strip():
            continue
        try:
            f = json.loads(line)
        except json.JSONDecodeError:
            problems.append(f"claude-security: line {n} of {src['report']} is not JSON")
            continue
        rows.append(
            {
                "severity": RANK.get(str(f.get("severity", "")).upper(), 0),
                "title": f.get("title", ""),
                "file": f.get("file", ""),
                "line": f.get("line", 0),
                "area": f.get("category", ""),
                "reproduction": f.get("exploit_scenario", ""),
                "fix": f.get("recommendation", ""),
                "cwe": f.get("cwe_id", ""),
                "verification": status,
                "sources": [
                    f"claude-security {f.get('claudeSecurityPluginFindingId') or f.get('id', '')}".strip()
                ],
            }
        )
    return src, rows


def cso(root, cutoff, problems):
    path = newest(os.path.join(root, ".gstack", "security-reports", "*.json"))
    if not path:
        return None, []
    try:
        r = json.load(open(path, encoding="utf-8"))
    except json.JSONDecodeError:
        problems.append(f"/cso: {os.path.relpath(path, root)} is not JSON")
        return None, []
    when = parse_time(r.get("date", ""))
    src = {
        "name": "/cso",
        "report": os.path.relpath(path, root),
        "date": r.get("date", ""),
        "mode": r.get("mode", ""),
        "scope": r.get("scope", ""),
        "stale": bool(cutoff and when and when < cutoff),
    }
    rows = []
    for f in r.get("findings", []):
        rows.append(
            {
                "severity": RANK.get(str(f.get("severity", "")).upper(), 0),
                "title": f.get("title", ""),
                "file": f.get("file", ""),
                "line": f.get("line", 0),
                "area": f.get("category", ""),
                "reproduction": f.get("exploit_scenario", ""),
                "fix": f.get("recommendation", ""),
                "cwe": "",
                "verification": f.get("verification", f.get("status", "")),
                "sources": [
                    f"/cso #{f.get('id', '')} (confidence {f.get('confidence', '?')})"
                ],
            }
        )
    return src, rows


def near(rows):
    """Pairs from different sources in the same file and area, other lines."""
    pairs = []
    for i, a in enumerate(rows):
        for b in rows[i + 1 :]:
            if (
                a["file"]
                and a["file"] == b["file"]
                and a["line"] != b["line"]
                and str(a["area"]).lower() == str(b["area"]).lower()
                and a["sources"][0].split()[0] != b["sources"][0].split()[0]
            ):
                pairs.append((a, b))
    return pairs


def merge(rows):
    by_site, out, merged = {}, [], 0
    for r in rows:
        key = (r["file"], r["line"]) if r["file"] else None
        if key and key in by_site:
            keep = by_site[key]
            keep["sources"] += r["sources"]
            if r["severity"] > keep["severity"]:
                for k in ("severity", "title", "area", "reproduction", "fix"):
                    keep[k] = r[k]
            merged += 1
            continue
        if key:
            by_site[key] = r
        out.append(r)
    out.sort(key=lambda r: -r["severity"])
    return out, merged


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--commit", default="")
    ap.add_argument("--since", default="")
    ap.add_argument("--commit-time", default="")
    ap.add_argument("--allow-stale", action="store_true")
    ap.add_argument("--out", default=".scratch/vapt-findings.json")
    a = ap.parse_args()
    since = parse_time(a.since) if a.since else None
    cutoff = parse_time(a.commit_time) if a.commit_time else since

    problems, sources, rows = [], [], []
    for src, found in (
        claude_security(a.root, a.commit, problems),
        cso(a.root, cutoff, problems),
    ):
        if src:
            sources.append(src)
            rows += found
    if not sources:
        print(
            "vapt-findings: 0 scanner reports found; run /cso or claude-security first, nothing checked",
            file=sys.stderr,
        )
        return 1
    for s in sources:
        if s["stale"]:
            what = (
                f"scanned {s['commit']}"
                if s["name"] == "claude-security"
                else f"dated {s['date']}"
            )
            rel = a.commit[:12] or a.commit_time or a.since
            if s["name"] == "/cso" and a.commit_time:
                rel = f"{a.commit[:12] or 'release'} committed {a.commit_time}"
            msg = f"{s['name']}: {s['report']} is stale ({what}; release is {rel})"
            if a.allow_stale:
                s["stale_accepted"] = True
                print(f"stale (accepted): {msg}")
            else:
                problems.append(msg)
    findings, merged = merge(rows)
    pairs = near(findings)
    for f in findings:
        f["severity"] = NAME[f["severity"]]
    out_dir = os.path.dirname(a.out) or "."
    os.makedirs(out_dir, exist_ok=True)
    ignore = os.path.join(out_dir, ".gitignore")
    if os.path.abspath(out_dir) != os.path.abspath(a.root) and not os.path.exists(ignore):
        with open(ignore, "w", encoding="utf-8") as fh:
            fh.write("*\n")
    with open(a.out, "w", encoding="utf-8") as fh:
        json.dump({"sources": sources, "findings": findings}, fh, indent=1)

    for p in problems:
        print(f"problem: {p}")
    for s in sources:
        if s["name"] == "claude-security":
            cov = s["scope"] + (f" since {s['base']}" if s["base"] else "")
        else:
            cov = " ".join(x for x in (s.get("mode"), s.get("scope")) if x) or "unknown"
        print(f"coverage: {s['name']} {cov}")
    for x, y in pairs:
        print(
            f"check: possible duplicate, {x['file']} lines {x['line']} and {y['line']} "
            f"({x['sources'][0]}; {y['sources'][0]}), same area {x['area']}; "
            "merge only if one root cause"
        )
    counts = {
        k: sum(1 for f in findings if f["severity"] == k)
        for k in ("Critical", "High", "Medium", "Low")
    }
    desc = ", ".join(
        f"{s['name']} {s.get('commit') or s.get('date')}"
        + (f" ({s['verification']})" if s.get("verification") else "")
        for s in sources
    )
    print(
        f"vapt-findings: {len(sources)} sources ({desc}), {len(findings)} findings "
        f"(Critical {counts['Critical']}, High {counts['High']}, Medium {counts['Medium']}, Low {counts['Low']}), "
        f"{merged} merged duplicates, written to {a.out}"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
