#!/usr/bin/env python3
"""Generate devguide/src/data/internals.json, the reference data behind the
developer guide (the internals site in devguide/).

Everything here is read from the kit itself, so the guide cannot drift from
the code: every skill's frontmatter, sections and files; every script's
header comment, functions, environment variables and the other kit scripts
it calls; the hook table; the agents; the make targets and which of them
`make check` runs; the stacks; the repository templates; the tests and
their header comments; the CI jobs; the evals; the CHANGELOG versions.
The skill categories and one-line summaries come from the handbook data
(site/src/data/handbook.json), which bin/gen-guide.py writes first.

The output is deterministic (sorted, no timestamps) so `make lint-docs` can
regenerate it and compare. Fails when any inventory comes out empty: a
guide built from zero skills or zero scripts documented nothing."""

import json
import pathlib
import re
import subprocess
import sys

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "devguide" / "src" / "data" / "internals.json"
HANDBOOK = ROOT / "site" / "src" / "data" / "handbook.json"


# Tool caches and installed dependencies are not part of the kit. They exist
# on a working machine (ruff leaves .ruff_cache beside the scripts it checked)
# and never in a fresh clone, so counting them made the output differ between
# a workstation and CI.
NOT_KIT = {
    "__pycache__",
    ".ruff_cache",
    ".pytest_cache",
    ".mypy_cache",
    "node_modules",
    ".venv",
    ".DS_Store",
}


def files_under(d):
    """Every file below d that belongs to the kit, sorted."""
    return [
        p
        for p in sorted(d.rglob("*"))
        if p.is_file() and not NOT_KIT.intersection(p.relative_to(d).parts)
    ]


def rel(p):
    return str(p.relative_to(ROOT))


def lines_of(p):
    try:
        return p.read_text(encoding="utf-8").count("\n")
    except UnicodeDecodeError:
        return 0


def frontmatter(text):
    m = re.search(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}, text
    fm = {}
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep and re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_-]*", k):
            fm[k] = v.strip().strip('"')
    return fm, text[m.end() :]


def sections(body):
    """Level-two headings in order, each with its text, outside code fences."""
    out, cur, buf, fence = [], None, [], False
    intro = []
    for line in body.splitlines():
        if line.startswith("```"):
            fence = not fence
        if not fence and line.startswith("## "):
            if cur is not None:
                out.append((cur, "\n".join(buf).strip()))
            cur, buf = line[3:].strip(), []
            continue
        (buf if cur is not None else intro).append(line)
    if cur is not None:
        out.append((cur, "\n".join(buf).strip()))
    return "\n".join(intro).strip(), out


def items(text, limit=40):
    """Top-level list items (bullets or numbers), each joined to one line."""
    got, cur = [], None
    for line in text.splitlines():
        m = re.match(r"^(?:[-*]|\d+\.)\s+(.*)", line)
        if m:
            if cur is not None:
                got.append(cur)
            cur = m.group(1).strip()
        elif cur is not None and line.startswith("  ") and line.strip():
            cur += " " + line.strip()
        elif cur is not None and not line.strip():
            got.append(cur)
            cur = None
    if cur is not None:
        got.append(cur)
    return [clip(g, 420) for g in got[:limit]]


def clip(s, n):
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def first_para(text):
    for para in re.split(r"\n\s*\n", text):
        p = para.strip()
        if p and not p.startswith("#") and not p.startswith("```"):
            return clip(p, 700)
    return ""


def split_tools(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            if cur.strip():
                out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


# ---------------------------------------------------------------- skills
def build_skills(hb):
    by_name = {s["name"]: s for s in hb.get("skills", [])}
    out = []
    for f in sorted((ROOT / "skills").glob("*/SKILL.md")):
        d = f.parent
        text = f.read_text(encoding="utf-8")
        fm, body = frontmatter(text)
        intro, secs = sections(body)
        names = [h for h, _ in secs]
        get = dict(secs)
        stack = "When this skill is active" in get
        files = [
            {"path": str(p.relative_to(d)), "lines": lines_of(p)}
            for p in files_under(d)
        ]
        groups = {}
        for fl in files:
            top = fl["path"].split("/")[0] if "/" in fl["path"] else "."
            groups[top] = groups.get(top, 0) + 1
        extra = {
            k: v
            for k, v in fm.items()
            if k
            not in (
                "name",
                "description",
                "allowed-tools",
                "argument-hint",
                "disable-model-invocation",
            )
        }
        h = by_name.get(fm.get("name", d.name), {})
        steps_src = get.get("Steps") or get.get("Rules that matter most") or ""
        out.append(
            {
                "name": fm.get("name", d.name),
                "category": h.get("category", "meta"),
                "what": h.get("what", clip(fm.get("description", ""), 200)),
                "when": h.get("when", ""),
                "description": fm.get("description", ""),
                "invocation": "command"
                if fm.get("disable-model-invocation") == "true"
                else "auto",
                "kind": "stack" if stack else "step",
                "args": fm.get("argument-hint", ""),
                "tools": split_tools(fm.get("allowed-tools", "")),
                "extra": extra,
                "intro": first_para(intro),
                "sections": [
                    {"title": t, "lines": b.count("\n") + (1 if b else 0)}
                    for t, b in secs
                ],
                "inputs": items(get.get("Inputs", ""), 14),
                "steps": items(steps_src, 24),
                "output": first_para(get.get("Output contract", "")),
                "gotchas": items(get.get("Gotchas", ""), 12),
                "layout": first_para(get.get("Layout", "")) if stack else "",
                "commands": items(get.get("Commands", ""), 12) if stack else [],
                "lines": text.count("\n"),
                "files": files,
                "groups": groups,
                "evals": (ROOT / "evals" / d.name / "evals.json").exists(),
                "hasSections": names,
            }
        )
    return out


# ---------------------------------------------------------------- scripts
BASH_FN = re.compile(r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{", re.M)
PY_FN = re.compile(r"^def ([a-zA-Z_][a-zA-Z0-9_]*)\(", re.M)
ENV = re.compile(r"\b(BEARING_[A-Z0-9_]+|CLAUDE_[A-Z0-9_]+)\b")
CALLS = re.compile(
    r"\b(brg-[a-z-]+|gen-[a-z-]+\.py|lint-[a-z-]+\.py|harness-eval\.py|skill-evals\.py)\b"
)


def header(text, py):
    """The leading comment block (bash) or module docstring (python)."""
    if py:
        m = re.search(r'^(?:#![^\n]*\n)?(?:#[^\n]*\n)*\s*"""(.*?)"""', text, re.S)
        return m.group(1).strip() if m else ""
    out = []
    for line in text.splitlines()[1 if text.startswith("#!") else 0 :]:
        if line.startswith("#"):
            out.append(re.sub(r"^# ?", "", line))
        elif out:
            break
    return "\n".join(out).strip()


def script_group(path):
    if path.startswith("hooks/"):
        return "hooks"
    n = pathlib.Path(path).name
    if n in ("install.sh", "brg-doctor", "brg-install-packs"):
        return "install"
    if n in ("brg-guard", "brg-harness", "brg-state-path"):
        return "guard"
    if n in ("brg-scaffold", "brg-adopt"):
        return "scaffold"
    if n in ("brg-tracker", "brg-rest", "brg-jira", "brg-gitlab", "brg-github"):
        return "tracker"
    if n in ("brg-autopilot", "brg-checklists", "brg-runbook-check"):
        return "workflow"
    if n.startswith("gen-"):
        return "generators"
    return "quality"


def build_scripts():
    paths = [ROOT / "install.sh"]
    paths += [
        p
        for p in sorted((ROOT / "bin").iterdir())
        if p.is_file() and not p.name.endswith((".txt", ".allow", ".skip"))
    ]
    paths += sorted((ROOT / "hooks" / "scripts").glob("*.sh"))
    out = []
    for p in paths:
        text = p.read_text(encoding="utf-8")
        py = text.startswith("#!/usr/bin/env python") or p.suffix == ".py"
        r = rel(p)
        fns = (PY_FN if py else BASH_FN).findall(text)
        calls = sorted({c for c in CALLS.findall(text) if c != p.name})
        out.append(
            {
                "path": r,
                "name": p.name,
                "lang": "python" if py else "bash",
                "group": script_group(r),
                "lines": text.count("\n"),
                "header": header(text, py),
                "functions": fns,
                "env": sorted(set(ENV.findall(text))),
                "calls": calls,
            }
        )
    for p in sorted((ROOT / "skills").glob("*/scripts/*")):
        if p.is_file() and p.suffix in (".sh", ".py") and "__pycache__" not in p.parts:
            text = p.read_text(encoding="utf-8")
            py = p.suffix == ".py"
            out.append(
                {
                    "path": rel(p),
                    "name": p.name,
                    "lang": "python" if py else "bash",
                    "group": "skill",
                    "skill": p.parts[-3],
                    "lines": text.count("\n"),
                    "header": header(text, py),
                    "functions": (PY_FN if py else BASH_FN).findall(text),
                    "env": sorted(set(ENV.findall(text))),
                    "calls": sorted({c for c in CALLS.findall(text) if c != p.name}),
                }
            )
    return out


# ---------------------------------------------------------------- hooks, agents
def build_hooks():
    data = json.loads((ROOT / "hooks" / "hooks.json").read_text())
    out = []
    for event, entries in data["hooks"].items():
        for e in entries:
            for h in e["hooks"]:
                m = re.search(r"hooks/scripts/([a-z-]+\.sh)", h["command"])
                script = m.group(1) if m else ""
                body = (
                    (ROOT / "hooks" / "scripts" / script).read_text() if script else ""
                )
                sub = re.findall(r"brg-guard[\"']?\s+([a-z-]+)", body) or re.findall(
                    r"guard\s+([a-z-]+)", body
                )
                out.append(
                    {
                        "event": event,
                        "matcher": e.get("matcher", ""),
                        "script": script,
                        "timeout": h.get("timeout", 0),
                        "guard": sorted(set(sub)),
                        "body": body.strip(),
                    }
                )
    return data.get("description", ""), out


def build_agents():
    out = []
    for f in sorted((ROOT / "agents").glob("*.md")):
        fm, body = frontmatter(f.read_text(encoding="utf-8"))
        _, secs = sections(body)
        out.append(
            {
                "name": fm.get("name", f.stem),
                "description": fm.get("description", ""),
                "tools": split_tools(fm.get("tools", "")),
                "disallowed": split_tools(fm.get("disallowedTools", "")),
                "model": fm.get("model", "inherit"),
                "maxTurns": fm.get("maxTurns", ""),
                "isolation": fm.get("isolation", ""),
                "intro": first_para(body.split("\n## ", 1)[0]),
                "sections": [t for t, _ in secs],
                "lines": body.count("\n"),
                "usedBy": sorted(
                    sk.parent.name
                    for sk in (ROOT / "skills").glob("*/SKILL.md")
                    # Agent names are plain words (critic, reviewer), so a
                    # skill uses one only where it names it as an agent: in
                    # backticks, as bearing:<name>, in an agent: field, or as
                    # "the <name> agent" or "the <name> format".
                    if re.search(
                        r"(`{0}`|^agent: {0}$|bearing:{0}\b|\b{0} (?:format|agent|subagent)\b)".format(
                            re.escape(fm.get("name", f.stem))
                        ),
                        sk.read_text(encoding="utf-8"),
                        re.M,
                    )
                ),
            }
        )
    return out


# ---------------------------------------------------------------- make, ci, tests
def build_make():
    text = (ROOT / "Makefile").read_text()
    targets = re.findall(r"^([a-zA-Z_-]+):[^=\n]*?## (.*)$", text, re.M)
    check = re.search(r"^check: (.*?) ##", text, re.M).group(1).split()
    return [
        {"name": t, "does": d.strip(), "inCheck": t in check} for t, d in targets
    ], check


def build_ci():
    text = (ROOT / ".gitlab-ci.yml").read_text()
    head = []
    for line in text.splitlines():
        if line.startswith("#"):
            head.append(re.sub(r"^# ?", "", line))
        else:
            break
    jobs = []
    for m in re.finditer(r"^(\.?[a-z][a-z0-9:_.-]*):\n((?:[ \t].*\n|\n)*)", text, re.M):
        name, block = m.group(1), m.group(2)
        if name in ("stages", "workflow", "variables", "default"):
            continue
        stage = re.search(r"^\s+stage:\s*(\S+)", block, re.M)
        ext = re.search(r"^\s+extends:\s*(\S+)", block, re.M)
        image = re.search(r"^\s+image:\s*(\S+)", block, re.M)
        jobs.append(
            {
                "name": name,
                "stage": stage.group(1) if stage else "",
                "extends": ext.group(1) if ext else "",
                "image": image.group(1) if image else "",
            }
        )
    # an extending job inherits its template's stage
    tmpl = {j["name"]: j for j in jobs}
    for j in jobs:
        if not j["stage"] and j["extends"] in tmpl:
            j["stage"] = tmpl[j["extends"]]["stage"]
    return "\n".join(head).strip(), [j for j in jobs if not j["name"].startswith(".")]


def build_tests():
    out = []
    for p in files_under(ROOT / "tests"):
        rp = p.relative_to(ROOT).parts
        if (
            not p.is_file()
            or "__pycache__" in rp
            or "fixtures" in rp
            or any(x.startswith(".") for x in rp)
        ):
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        py = p.suffix == ".py"
        h = header(text, py)
        asserts = len(re.findall(r"\b(assert_[a-z_]+|ok |check )", text))
        out.append(
            {
                "path": rel(p),
                "kind": rp[1] if len(rp) > 2 else "runner",
                "lines": text.count("\n"),
                "header": clip(h, 600),
                "asserts": asserts,
            }
        )
    fixtures = len(files_under(ROOT / "tests" / "fixtures"))
    return out, fixtures


# ---------------------------------------------------------------- stacks, templates
def build_stacks():
    out = []
    for f in sorted((ROOT / "skills").glob("*/templates*/stack.json")):
        d = json.loads(f.read_text())
        tdir = f.parent
        files = [str(p.relative_to(tdir)) for p in files_under(tdir)]
        d.update({"skill": f.parts[-3], "dir": rel(tdir), "files": files})
        out.append(d)
    return sorted(out, key=lambda s: s["id"])


def build_templates():
    base = ROOT / "templates"
    return [
        {"path": str(p.relative_to(base)), "lines": lines_of(p)}
        for p in files_under(base)
    ]


def build_changelog():
    text = (ROOT / "CHANGELOG.md").read_text()
    out = []
    for m in re.finditer(r"^## \[?([0-9][^\]\s]*|Unreleased)\]?(.*)$", text, re.M):
        start = m.end()
        nxt = re.search(r"^## ", text[start:], re.M)
        body = text[start : start + nxt.start()] if nxt else text[start:]
        heads = re.findall(r"^### (.+)$", body, re.M)
        bullets = len(re.findall(r"^- ", body, re.M))
        date = re.search(r"(\d{4}-\d{2}-\d{2})", m.group(2))
        out.append(
            {
                "version": m.group(1),
                "date": date.group(1) if date else "",
                "groups": heads,
                "entries": bullets,
                "summary": first_para(re.sub(r"^### .*$", "", body, flags=re.M)),
            }
        )
    return out


def build_settings():
    """The repository permission model and what every session loads, in counts."""
    st = json.loads(
        (ROOT / "templates" / "repo" / ".claude" / "settings.json").read_text()
    )
    perm = st.get("permissions", {})
    sb = st.get("sandbox", {})
    fs = sb.get("filesystem", {})
    rules = sorted((ROOT / "templates" / "repo" / ".claude" / "rules").glob("*.md"))
    unscoped = [
        r for r in rules if "paths:" not in "".join(r.read_text().splitlines(True)[:5])
    ]
    agents_b = (ROOT / "templates" / "repo" / "AGENTS.md").stat().st_size
    claude_b = (ROOT / "templates" / "repo" / "CLAUDE.md").stat().st_size
    unscoped_b = sum(r.stat().st_size for r in unscoped)
    return {
        "allow": len(perm.get("allow", [])),
        "ask": len(perm.get("ask", [])),
        "deny": len(perm.get("deny", [])),
        "defaultMode": perm.get("defaultMode", ""),
        "askSamples": perm.get("ask", [])[:8],
        "domains": len(sb.get("network", {}).get("allowedDomains", [])),
        "allowWrite": fs.get("allowWrite", []),
        "denyRead": fs.get("denyRead", []),
        "denyWrite": fs.get("denyWrite", []),
        "rules": [r.name for r in rules],
        "unscopedRules": [r.name for r in unscoped],
        "sessionBytes": {
            "agents": agents_b,
            "claude": claude_b,
            "unscopedRules": unscoped_b,
        },
        "sessionTokens": (agents_b + claude_b + unscoped_b) // 4,
    }


def build_guard_rules():
    """The blocked verb table as the guard itself prints it (tool, pattern, label)."""
    out = subprocess.run(
        ["bash", str(ROOT / "bin" / "brg-guard"), "--verbs"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    rows = [line.split("\t") for line in out.splitlines() if line.strip()]
    return [
        {
            "tool": r[0],
            "pattern": r[1] if len(r) > 1 else "",
            "label": r[2] if len(r) > 2 else "",
        }
        for r in rows
    ]


def build_autopilot():
    """The stage table from bin/brg-autopilot itself (skill and gate per stage)."""
    import importlib.machinery
    import importlib.util

    path = str(ROOT / "bin" / "brg-autopilot")
    loader = importlib.machinery.SourceFileLoader("autopilot", path)
    spec = importlib.util.spec_from_loader("autopilot", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return {
        "maxAttempts": mod.MAX_ATTEMPTS,
        "stages": [{"name": n, "skill": sk, "gate": g} for n, sk, g in mod.STAGES],
    }


def main():
    hb = json.loads(HANDBOOK.read_text()) if HANDBOOK.exists() else {}
    skills = build_skills(hb)
    scripts = build_scripts()
    hook_desc, hooks = build_hooks()
    agents = build_agents()
    make, check = build_make()
    ci_head, ci = build_ci()
    tests, fixtures = build_tests()
    stacks = build_stacks()
    templates = build_templates()
    changelog = build_changelog()
    evals = sorted(p.parent.name for p in (ROOT / "evals").glob("*/evals.json"))
    pending_file = ROOT / "evals" / ".pending"
    pending = (
        [
            line.strip()
            for line in pending_file.read_text().splitlines()
            if line.strip() and not line.startswith("#")
        ]
        if pending_file.exists()
        else []
    )
    counts = {
        "skills": len(skills),
        "commandSkills": sum(s["invocation"] == "command" for s in skills),
        "stackSkills": sum(s["kind"] == "stack" for s in skills),
        "scripts": len(scripts),
        "scriptLines": sum(s["lines"] for s in scripts),
        "hooks": len(hooks),
        "agents": len(agents),
        "makeTargets": len(make),
        "gates": len(check),
        "tests": len(tests),
        "fixtures": fixtures,
        "stacks": len(stacks),
        "templates": len(templates),
        "ciJobs": len(ci),
        "evals": len(evals),
        "skillFiles": sum(len(s["files"]) for s in skills),
    }
    empty = [
        k
        for k in (
            "skills",
            "scripts",
            "hooks",
            "agents",
            "makeTargets",
            "tests",
            "stacks",
            "templates",
            "ciJobs",
        )
        if not counts[k]
    ]
    if empty:
        sys.exit(
            f"gen-devguide: empty inventory ({', '.join(empty)}), nothing documented"
        )
    data = {
        "version": (ROOT / "VERSION").read_text().strip(),
        "counts": counts,
        "categories": hb.get("categories", {}),
        "skills": skills,
        "scripts": scripts,
        "hookDescription": hook_desc,
        "hooks": hooks,
        "agents": agents,
        "make": make,
        "check": check,
        "ciHeader": ci_head,
        "ci": ci,
        "tests": tests,
        "stacks": stacks,
        "templates": templates,
        "changelog": changelog,
        "evals": evals,
        "evalsPending": pending,
        "guardRules": build_guard_rules(),
        "settings": build_settings(),
        "autopilot": build_autopilot(),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(
        f"devguide: {counts['skills']} skills, {counts['scripts']} scripts, {counts['hooks']} hooks, {counts['agents']} agents, "
        f"{counts['makeTargets']} make targets, {counts['tests']} tests, {counts['stacks']} stacks written to {rel(OUT)}"
    )


if __name__ == "__main__":
    main()
