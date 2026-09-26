#!/usr/bin/env python3
"""arch_check: the architecture set high-level-design writes is complete and agrees
with itself, computed from the files.

  - HLD (docs/design/*-hld.md, or the paths given): a "- Status:" line; the
    sections Summary, What gets built, External integrations, Analytics,
    Outside the standard stack, Repository plan and What the review found;
    a diagram path docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>.svg
    in the summary; every major section (architecture, data, external
    integrations, scaling, security, observability, analytics, rollout)
    ends with "**Risks this leaves open**" and at least one bullet;
    "Deliberately not integrated" with at least one bullet; a "What gets
    built" table (Component | Kind | Stack | Responsibility | Repository)
    whose Repository cells name a repo-plan entry or start "existing" or
    "none"; a review with a "Reviewed by:" line and findings headed
    "### BLOCKER|MAJOR|MINOR|NIT: <title>", each with "Conflicts with:",
    "Fix:" and "Status: open|fixed|accepted". Approved with an open BLOCKER,
    an open conflict or no drawn diagram is a problem.
  - Tenets (<arch>/tenets.md): 5 to 8 "## " tenets, each with a bold rule
    line and "A breach looks like:" followed by text.
  - Decisions index (<arch>/decisions.md): a table whose header has
    Reversibility; every ADR file in the ADR directory appears by number,
    no row names a missing file, reversibility starts cheap, awkward or
    irreversible, status is Proposed, Accepted, Superseded, Deprecated or
    Rejected. "Conflicts that were settled" holds "### " entries, each with
    Between:, Decision, Why, "Settled by:" and "What now has to change to
    match:", or one "None found:" line saying what was compared.
  - Repo plan (<arch>/repo-plan.json): project and group, a non-empty repos
    list; each name PascalCase, prefixed by the project and unique;
    git_path <group>/<Client|Server|Infrastructure>/<name>, the subgroup
    matching the stack's type; stack a kit stack id (from
    */templates*/stack.json in every Bearing plugin's skills, as
    bin/brg-kit-paths lists them) or "none" with a stack_note;
    a responsibility; apps entries with path, name and for, paths unique.

Usage: arch_check.py [hld files...] [--arch docs/architecture] [--adr-dir docs/adr] [--kit K]
Prints one "problem:" line per failure, the counts and the gate line; exits
1 on any problem, or when no HLD or no architecture file was read.
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys

SEVERITIES = ("BLOCKER", "MAJOR", "MINOR", "NIT")
MAJOR_SECTIONS = (
    "architecture",
    "data",
    "external integrations",
    "scaling",
    "security",
    "observability",
    "analytics",
    "rollout",
)
REQUIRED = (
    "summary",
    "what gets built",
    "external integrations",
    "analytics",
    "outside the standard stack",
    "repository plan",
    "what the review found",
)
SUBGROUPS = ("Client", "Server", "Infrastructure")
PASCAL = re.compile(r"^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]*)*$")
DIAGRAM = re.compile(
    r"docs/architecture/diagrams/([A-Za-z0-9]+)_SystemArchitecture_v(\d+)\.svg"
)
ADR_FILE = re.compile(r"^(?:ADR-|adr-)?(\d+)-.+\.(?:md|rst|adoc)$")


def sections(text, level="## "):
    """[(heading, body)] for each heading of this level; fenced code dropped."""
    text = re.sub(r"^```.*?^```", "", text, flags=re.M | re.S)
    marks = [m for m in re.finditer(r"^" + re.escape(level) + r"(.+)$", text, re.M)]
    out = []
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        out.append((m.group(1).strip(), text[m.end() : end]))
    return out


def norm(heading):
    return re.sub(r"^\d+\.\s*", "", heading).strip().lower()


def bullets_after(body, marker):
    """Non-empty '- ' lines after marker, up to the next heading or bold line."""
    i = body.find(marker)
    if i < 0:
        return None
    n = 0
    for line in body[i + len(marker) :].splitlines()[1:]:
        s = line.strip()
        if s.startswith("#") or s.startswith("**"):
            break
        if re.match(r"^[-*] \S", s):
            n += 1
    return n


def table_rows(body):
    rows = []
    for line in body.splitlines():
        s = line.strip()
        if s.startswith("|") and not re.match(r"^\|[\s:|-]+\|$", s):
            rows.append([c.strip() for c in s.strip("|").split("|")])
    return rows


def skill_roots(kit):
    """The skills folders of every Bearing plugin present: the stack templates
    ship in bearing-backend and bearing-apps, found by bin/brg-kit-paths."""
    resolver = os.path.join(kit, "bin", "brg-kit-paths")
    if os.path.isfile(resolver):
        try:
            r = subprocess.run(["bash", resolver, "--skills"], capture_output=True, text=True, timeout=20)
            roots = [line for line in r.stdout.splitlines() if line.strip()]
            if r.returncode == 0 and roots:
                return roots
        except (OSError, subprocess.SubprocessError):
            pass
    return [os.path.join(kit, "skills")]


def kit_stacks(kit):
    stacks = {}
    for f in (
        f
        for root in skill_roots(kit)
        for f in glob.glob(os.path.join(root, "*", "templates*", "stack.json"))
    ):
        try:
            d = json.load(open(f, encoding="utf-8"))
            stacks[d["id"]] = d.get("type", "")
        except (ValueError, KeyError, OSError):
            continue
    return stacks


def check_plan(path, stacks, problems):
    names = set()
    if not os.path.isfile(path):
        problems.append(f"{path}: missing")
        return names, 0
    try:
        plan = json.load(open(path, encoding="utf-8"))
    except ValueError as e:
        problems.append(f"{path}: not JSON ({e})")
        return names, 0
    project, group = plan.get("project", ""), plan.get("group", "")
    if not PASCAL.match(project or ""):
        problems.append(f"{path}: project '{project}' is not PascalCase")
    if not group:
        problems.append(f"{path}: no group")
    repos = plan.get("repos") or []
    if not repos:
        problems.append(f"{path}: 0 repos")
    for r in repos:
        name = r.get("name", "")
        if not PASCAL.match(name) or not name.startswith(project) or name == project:
            problems.append(
                f"{path}: repo '{name}' is not <Project><Component> PascalCase"
            )
        if name in names:
            problems.append(f"{path}: duplicate repo {name}")
        names.add(name)
        stack = r.get("stack", "")
        if stack == "none":
            if not r.get("stack_note"):
                problems.append(f"{path}: {name} has stack none and no stack_note")
        elif stack not in stacks:
            problems.append(f"{path}: {name} stack '{stack}' is not a kit stack id")
        gp = r.get("git_path", "")
        parts = gp.split("/")
        if (
            len(parts) != 3
            or parts[0] != group
            or parts[1] not in SUBGROUPS
            or parts[2] != name
        ):
            problems.append(
                f"{path}: {name} git_path '{gp}' is not {group}/<Client|Server|Infrastructure>/{name}"
            )
        else:
            kind = stacks.get(stack, "")
            want = {
                "Client": "Client",
                "Server": "Server",
                "Infra": "Infrastructure",
            }.get(kind.split("/")[0])
            if want and parts[1] != want:
                problems.append(
                    f"{path}: {name} is a {kind} stack under {parts[1]}, want {want}"
                )
        if not (r.get("responsibility") or "").strip():
            problems.append(f"{path}: {name} has no responsibility")
        seen = set()
        for a in r.get("apps") or []:
            if not all((a.get(k) or "").strip() for k in ("path", "name", "for")):
                problems.append(f"{path}: {name} has an app without path, name and for")
            if a.get("path") in seen:
                problems.append(f"{path}: {name} app path {a.get('path')} twice")
            seen.add(a.get("path"))
    return names, len(repos)


def check_tenets(path, problems):
    if not os.path.isfile(path):
        problems.append(f"{path}: missing")
        return 0
    tenets = sections(open(path, encoding="utf-8").read())
    if not 5 <= len(tenets) <= 8:
        problems.append(f"{path}: {len(tenets)} tenets, want 5 to 8")
    for head, body in tenets:
        if not re.search(r"^\*\*[^*].*\*\*\s*$", body, re.M):
            problems.append(f"{path}: tenet '{head}' has no bold rule line")
        if not re.search(r"A breach looks like:_?\*{0,2}\s*\S", body):
            problems.append(
                f"{path}: tenet '{head}' has no 'A breach looks like:' example"
            )
    return len(tenets)


def check_decisions(path, adr_dir, problems):
    """Returns (index rows, ADR files, conflicts, open conflicts)."""
    if not os.path.isfile(path):
        problems.append(f"{path}: missing")
        return 0, 0, 0, 0
    text = open(path, encoding="utf-8").read()
    rows, header = [], None
    for head, body in sections(text):
        t = table_rows(body)
        if t and any("reversibility" in c.lower() for c in t[0]):
            header, rows = [c.lower() for c in t[0]], t[1:]
            break
    if header is None:
        problems.append(f"{path}: no index table with a Reversibility column")
        header = []
    col = {
        k: next((i for i, c in enumerate(header) if k in c), None)
        for k in ("id", "status", "reversibility")
    }
    listed = {}
    for r in rows:
        if col["id"] is None or col["id"] >= len(r):
            continue
        m = re.search(r"(\d+)", r[col["id"]])
        if not m:
            problems.append(f"{path}: row id '{r[col['id']]}' has no number")
            continue
        listed[int(m.group(1))] = r[col["id"]]
        rev = (
            r[col["reversibility"]].lower()
            if col["reversibility"] is not None and col["reversibility"] < len(r)
            else ""
        )
        if not re.match(r"^(cheap|awkward|irreversible)\b", rev):
            problems.append(
                f"{path}: {r[col['id']]} reversibility '{rev}' is not cheap, awkward or irreversible"
            )
        st = (
            r[col["status"]]
            if col["status"] is not None and col["status"] < len(r)
            else ""
        )
        if not re.match(r"^(Proposed|Accepted|Superseded|Deprecated|Rejected)\b", st):
            problems.append(
                f"{path}: {r[col['id']]} status '{st}' is not a known status"
            )
    files = {}
    if os.path.isdir(adr_dir):
        for f in sorted(os.listdir(adr_dir)):
            m = ADR_FILE.match(f)
            if m and int(m.group(1)) != 0:
                files[int(m.group(1))] = f
    for n, f in files.items():
        if n not in listed:
            problems.append(f"{path}: {adr_dir}/{f} is not in the index")
    for n, rid in listed.items():
        if n not in files:
            problems.append(f"{path}: {rid} has no file in {adr_dir}")
    conflicts = opened = 0
    body = next(
        (b for h, b in sections(text) if "conflicts that were settled" in h.lower()),
        None,
    )
    if body is None:
        problems.append(f"{path}: no 'Conflicts that were settled' section")
    else:
        entries = sections(body, "### ")
        if not entries and not re.search(r"^None found:\s*\S", body, re.M):
            problems.append(
                f"{path}: conflicts section has no entries and no 'None found:' line"
            )
        for head, eb in entries:
            conflicts += 1
            for key in (
                "Between:",
                "Decision",
                "Why",
                "Settled by:",
                "What now has to change to match:",
            ):
                if key not in eb:
                    problems.append(f"{path}: conflict '{head}' has no '{key}'")
            m = re.search(r"Settled by:\**\s*(.*)", eb)
            who = (m.group(1).strip() if m else "").lower()
            if not who:
                problems.append(
                    f"{path}: conflict '{head}' names nobody under Settled by"
                )
            elif who.startswith("open"):
                opened += 1
    return len(rows), len(files), conflicts, opened


def check_hld(path, plan_names, arch, problems, counts):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^- Status:\s*(\w+)", text, re.M)
    status = m.group(1) if m else ""
    if status not in ("Draft", "Reviewed", "Approved"):
        problems.append(f"{path}: no '- Status: Draft|Reviewed|Approved' line")
    secs = sections(text)
    names = [norm(h) for h, _ in secs]
    for want in REQUIRED:
        if not any(n.startswith(want) for n in names):
            problems.append(f"{path}: no '{want}' section")
    diagram = DIAGRAM.search(text)
    if not diagram:
        problems.append(
            f"{path}: no diagram path docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>.svg"
        )
    elif status == "Approved" and not os.path.isfile(diagram.group(0)):
        problems.append(
            f"{path}: Approved but {diagram.group(0)} is not drawn (architecture-diagram)"
        )
    blockers_open = 0
    for head, body in secs:
        n = norm(head)
        if any(n.startswith(s) for s in MAJOR_SECTIONS):
            k = bullets_after(body, "**Risks this leaves open**")
            if not k:
                problems.append(
                    f"{path}: '{head}' has no 'Risks this leaves open' bullets"
                )
            counts["risks"] += k or 0
        if n.startswith("external integrations"):
            k = bullets_after(body, "Deliberately not integrated")
            if not k:
                problems.append(
                    f"{path}: '{head}' lists nothing under 'Deliberately not integrated'"
                )
        if n.startswith("what gets built"):
            rows = table_rows(body)
            if not rows or [c.lower() for c in rows[0]] != [
                "component",
                "kind",
                "stack",
                "responsibility",
                "repository",
            ]:
                problems.append(
                    f"{path}: 'What gets built' table header is not Component | Kind | Stack | Responsibility | Repository"
                )
                rows = [[]]
            for r in rows[1:]:
                counts["components"] += 1
                repo = r[-1] if r else ""
                if repo not in plan_names and not re.match(
                    r"^(existing|none)\b", repo, re.I
                ):
                    problems.append(
                        f"{path}: component '{r[0]}' repository '{repo}' is not in {arch}/repo-plan.json"
                    )
            if len(rows) < 2:
                problems.append(f"{path}: 'What gets built' has 0 components")
        if n.startswith("what the review found"):
            if not re.search(r"^Reviewed by:\s*\S", body, re.M):
                problems.append(
                    f"{path}: the review has no 'Reviewed by:' line (critic is mandatory)"
                )
            for fh, fb in sections(body, "### "):
                sev = fh.split(":")[0].strip().upper()
                if sev not in SEVERITIES:
                    problems.append(
                        f"{path}: finding '{fh}' is not graded BLOCKER, MAJOR, MINOR or NIT"
                    )
                    continue
                counts[sev] += 1
                for key in ("Conflicts with:", "Fix:"):
                    if key not in fb:
                        problems.append(f"{path}: finding '{fh}' has no '{key}'")
                sm = re.search(r"Status:\**\s*(open|fixed|accepted)", fb, re.I)
                if not sm:
                    problems.append(
                        f"{path}: finding '{fh}' has no 'Status: open|fixed|accepted'"
                    )
                elif sev == "BLOCKER" and sm.group(1).lower() == "open":
                    blockers_open += 1
    if status == "Approved" and blockers_open:
        problems.append(f"{path}: Approved with {blockers_open} open BLOCKER")
    counts["blockers_open"] += blockers_open
    return status


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hld", nargs="*")
    ap.add_argument("--arch", default="docs/architecture")
    ap.add_argument("--adr-dir", default="docs/adr")
    ap.add_argument(
        "--kit",
        default=os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "..")
        ),
    )
    a = ap.parse_args()
    hlds = a.hld or sorted(glob.glob("docs/design/*-hld.md"))
    if not hlds:
        print("arch-check: 0 HLD files, nothing checked", file=sys.stderr)
        return 1
    stacks = kit_stacks(a.kit)
    if not stacks:
        print(
            f"arch-check: 0 kit stacks under {a.kit} and its sibling plugins, nothing to check "
            "stack ids against (the stack templates ship in bearing-backend and bearing-apps: "
            "/plugin install bearing-backend@bearing)",
            file=sys.stderr,
        )
        return 1
    problems = []
    counts = {"risks": 0, "components": 0, "blockers_open": 0}
    counts.update({s: 0 for s in SEVERITIES})
    names, n_repos = check_plan(
        os.path.join(a.arch, "repo-plan.json"), stacks, problems
    )
    n_tenets = check_tenets(os.path.join(a.arch, "tenets.md"), problems)
    n_rows, n_adrs, n_conf, n_open = check_decisions(
        os.path.join(a.arch, "decisions.md"), a.adr_dir, problems
    )
    approved = 0
    for h in hlds:
        if not os.path.isfile(h):
            problems.append(f"{h}: missing")
            continue
        if check_hld(h, names, a.arch, problems, counts) == "Approved":
            approved += 1
    if approved and n_open:
        problems.append(
            f"{a.arch}/decisions.md: {n_open} conflicts still open under an Approved HLD"
        )
    for p in problems:
        print(f"problem: {p}")
    print(
        f"arch-check: {len(hlds)} HLD ({approved} Approved), {counts['components']} components, {n_repos} repos, "
        f"{n_tenets} tenets, {n_rows} indexed ADRs of {n_adrs} files, {n_conf} conflicts ({n_open} open), "
        f"{counts['risks']} risks, findings BLOCKER {counts['BLOCKER']} (open {counts['blockers_open']}), "
        f"MAJOR {counts['MAJOR']}, MINOR {counts['MINOR']}, NIT {counts['NIT']}; {len(problems)} problems"
    )
    print(f"Gate: {'passed' if not problems else f'FAILED ({len(problems)} problems)'}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
