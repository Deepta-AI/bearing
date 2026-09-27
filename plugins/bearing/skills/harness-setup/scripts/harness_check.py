#!/usr/bin/env python3
"""harness_check.py: the checks brg-harness does not make, for one harness.

  harness_check.py audit  <harness> [--dir D]   before writing: what the repo
      already says and does that the setup must account for
  harness_check.py extend <harness> [--dir D]   carry .claude/settings.json's
      shell denies (and make targets that hide a deploy) into the harness
  harness_check.py check  <harness> [--dir D]   feed the harness's own event
      JSON to every shell hook it is configured to run and compare the
      verdicts with .claude/settings.json

Every subcommand prints how many items it examined and exits 1 when that is
zero. check exits 1 on any gap. Standard library only; the hooks need bash
and jq. Nothing here runs a denied command: hooks are fed event JSON.
"""

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "templates", "settings-deny.sh")
CODEX_DOC_LIMIT = 32 * 1024
RISKY = re.compile(
    r"\b(push|deploy|merge|kubectl|helm|terraform|force|--no-verify|in place|release)\b",
    re.I,
)
DEPLOY_VERBS = re.compile(
    r"\b(kubectl|helm|terraform\s+apply|tofu\s+apply|pulumi\s+up|flyctl|fly\s+deploy|gcloud\s+\S+\s+deploy|"
    r"aws\s+\S*\s*deploy|az\s+\S+\s+deploy|docker\s+push|git\s+push|npm\s+publish|vercel|netlify\s+deploy|ansible-playbook)\b"
)

# Files each harness's generator writes; checked against .gitignore before writing.
WRITES = {
    "cursor": [
        ".cursor/hooks.json",
        ".cursor/rules/brg-agents.mdc",
        ".bearing/hooks/cursor-shell.sh",
        ".bearing/bin/brg-guard",
    ],
    "codex": [
        ".codex/hooks.json",
        ".codex/rules/bearing.rules",
        ".bearing/hooks/codex-pretool.sh",
        ".bearing/bin/brg-guard",
    ],
    "gemini": [
        ".gemini/settings.json",
        "GEMINI.md",
        ".bearing/hooks/gemini-pretool.sh",
        ".bearing/bin/brg-guard",
    ],
    "copilot": [
        ".github/hooks/bearing.json",
        ".github/copilot-instructions.md",
        ".bearing/hooks/copilot-pretool.sh",
    ],
    "opencode": [
        ".opencode/plugins/brg-guard.js",
        "opencode.json",
        ".bearing/bin/brg-guard",
    ],
    "windsurf": [
        ".devin/hooks.json",
        ".devin/rules/brg-agents.md",
        ".bearing/hooks/windsurf-run.sh",
    ],
    "cline": [".clinerules/hooks/PreToolUse", ".bearing/bin/brg-guard"],
    "kiro": [".kiro/hooks/brg-guard.json", ".bearing/hooks/kiro-pretool.sh"],
    "zed": [".zed/settings.json", ".rules"],
}
# Instruction and config files another harness may already read.
OTHER_FILES = [
    ".cursorrules",
    ".windsurfrules",
    ".rules",
    "GEMINI.md",
    "opencode.json",
    ".github/copilot-instructions.md",
    ".codex/config.toml",
    ".gemini/settings.json",
    ".cursor/hooks.json",
    ".codex/hooks.json",
    ".zed/settings.json",
]
OTHER_GLOBS = [
    ".cursor/rules",
    ".github/instructions",
    ".clinerules",
    ".devin/rules",
    ".kiro/steering",
    ".codex/rules",
]
SKIP_DIRS = {".git", "node_modules", "vendor", ".venv", "dist", "build", ".scratch"}


def git(d, *a):
    r = subprocess.run(["git", "-C", d, *a], capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


# ---------------------------------------------------------------- settings
def settings_entries(d):
    """(kind, words) from .claude/settings.json: deny/ask Bash patterns, Read denies."""
    p = os.path.join(d, ".claude", "settings.json")
    if not os.path.isfile(p):
        return None
    perms = json.load(open(p)).get("permissions", {})
    out = []
    for kind in ("deny", "ask"):
        for e in perms.get(kind, []):
            m = re.fullmatch(r"Bash\((.*)\)", e.strip())
            if m:
                words = re.sub(r":?\*$", "", m.group(1)).strip()
                if words:
                    out.append((kind, words))
                continue
            m = re.fullmatch(r"Read\((.*)\)", e.strip())
            if m and kind == "deny" and "*" not in m.group(1):
                out.append(("path", re.sub(r"^\./", "", m.group(1).strip())))
    return out


def make_targets(d):
    """{target: (prerequisites, recipe text)} from the root Makefile (plain rules only)."""
    p = os.path.join(d, "Makefile")
    if not os.path.isfile(p):
        return {}
    targets, cur = {}, None
    for line in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"^([A-Za-z0-9_.-]+)\s*:(?!=)([^#;]*)", line)
        if m and not line.startswith("\t"):
            cur = None if m.group(1).startswith(".") else m.group(1)
            if cur:
                targets[cur] = (m.group(2).split(), "")
        elif line.startswith("\t") and cur:
            targets[cur] = (targets[cur][0], targets[cur][1] + line)
        elif line.strip() and not line.startswith("\t"):
            cur = None
    return targets


def hidden_targets(d, entries):
    """Make targets that run a denied or deploy command, in their recipe or through a
    prerequisite or a $(MAKE) call: a hook sees only 'make <t>'. [(target, why)]"""
    denied = [w for k, w in (entries or []) if k == "deny"]
    targets = make_targets(d)
    direct = {}
    for t, (_, recipe) in targets.items():
        why = [w for w in denied if not w.startswith("make ")
               and re.search(r"(^|[\s;&|(])" + re.escape(w) + r"\b", recipe)]
        if not why and DEPLOY_VERBS.search(recipe):
            why = [DEPLOY_VERBS.search(recipe).group(0)]
        if why:
            direct[t] = f"runs '{why[0]}' in its recipe"
    for w in denied:
        if w.startswith("make ") and len(w.split()) == 2 and w.split()[1] in targets:
            direct.setdefault(w.split()[1], "is denied in .claude/settings.json")
    found = dict(direct)
    changed = True
    while changed:
        changed = False
        for t, (pre, recipe) in targets.items():
            if t in found:
                continue
            calls = pre + re.findall(r"(?:\$\(MAKE\)|\$\{MAKE\}|\bmake)\s+(?:-\S+\s+)*([A-Za-z0-9_.-]+)", recipe)
            hit = next((c for c in calls if c in found), None)
            if hit:
                found[t] = f"reaches make {hit}, which {found[hit]}"
                changed = True
    return [(t, why) for t, why in found.items()]


def find_agents(d, p, find):
    rel = os.path.relpath(p, d)
    data = open(p, "rb").read()
    print(f"  {rel}: {len(data)} bytes")
    if rel == "AGENTS.md" and len(data) > CODEX_DOC_LIMIT:
        late, off = [], 0
        for line in data.split(b"\n"):
            text = line.decode("utf-8", "replace")
            if off >= CODEX_DOC_LIMIT and RISKY.search(text):
                late.append((off, text.strip()))
            off += len(line) + 1
        find(
            f"AGENTS.md is {len(data)} bytes, over Codex's default project_doc_max_bytes ({CODEX_DOC_LIMIT}); "
            f"text past byte {CODEX_DOC_LIMIT} is silently dropped. {len(late)} rule line(s) about push/deploy lie past it"
            + (f", first at byte {late[0][0]}: {late[0][1][:70]}" if late else "")
            + ". Move those rules up or the bulk (tables, references) out; raising the limit only helps Codex."
        )
    if rel == "AGENTS.md":
        return
    how = ("Codex reads it INSTEAD of the AGENTS.md beside it" if rel.endswith("override.md")
           else "read after the root, so it wins for files under it")
    for n, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
        if RISKY.search(line):
            find(f"{rel}:{n} ({how}): {line.strip()[:90]}")


# ---------------------------------------------------------------- audit
def audit(d, harness):
    checked, findings = 0, []

    def find(msg):
        findings.append(msg)
        print("  FINDING " + msg)

    print("== Claude Code settings (what 'the same guardrails' means here)")
    entries = settings_entries(d)
    if entries is None:
        print("  no .claude/settings.json: the vendored guard's table is the deny list")
    else:
        for k, w in entries:
            checked += 1
            print(f"  {k:5} {w}")
    for t, why in hidden_targets(d, entries):
        checked += 1
        covered = any(
            k == "deny" and w.split()[:2] == ["make", t] for k, w in (entries or [])
        )
        find(
            f"make {t} {why}; a shell hook sees only 'make {t}'"
            + ("" if covered else " and .claude/settings.json does not deny it either")
            + ". Deny the target by name; never edit or run it."
        )

    print("== Instruction files (AGENTS.md and AGENTS.override.md at every depth)")
    for root, dirs, files in os.walk(d):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for name in ("AGENTS.md", "AGENTS.override.md"):
            if name in files:
                checked += 1
                find_agents(d, os.path.join(root, name), find)

    print("== Files another harness already reads")
    paths = [f for f in OTHER_FILES if os.path.isfile(os.path.join(d, f))]
    for g in OTHER_GLOBS:
        gd = os.path.join(d, g)
        if os.path.isdir(gd):
            for root, _, files in os.walk(gd):
                paths += [os.path.relpath(os.path.join(root, f), d) for f in files]
        elif os.path.isfile(gd):
            paths.append(g)
    for rel in sorted(set(paths)):
        checked += 1
        text = open(os.path.join(d, rel), encoding="utf-8", errors="replace").read()
        always = re.search(r"^alwaysApply:\s*true", text, re.M)
        print(f"  {rel}{' (always applied)' if always else ''}")
        for n, line in enumerate(text.splitlines(), 1):
            if RISKY.search(line):
                find(f"{rel}:{n} check it agrees with AGENTS.md: {line.strip()[:90]}")
        if rel == ".codex/config.toml":
            for key, bad in (
                ("approval_policy", r'"never"'),
                ("sandbox_mode", r'"danger-full-access"'),
                ("inherit", r'"all"'),
                ("network_access", r"true"),
            ):
                if re.search(rf"^\s*{key}\s*=\s*{bad}", text, re.M):
                    find(
                        f".codex/config.toml sets {key} = {bad}: a trusted project applies this to every "
                        "contractor who opens it. Make it safe in the file (workspace-write, on-request, network off, "
                        "inherit core) and tell the user."
                    )

    print("== Git hooks (the push confirmation holds only if git runs them)")
    _, hp = git(d, "config", "--get", "core.hooksPath")
    hdir = hp or (
        ".githooks" if os.path.isdir(os.path.join(d, ".githooks")) else ".git/hooks"
    )
    print(f"  core.hooksPath in this clone: {hp or 'unset'}")
    if not hp and os.path.isdir(os.path.join(d, ".githooks")):
        find(
            "core.hooksPath is unset: .githooks/ does not run in this clone (nor in any clone until `make hooks` or "
            "`git config core.hooksPath .githooks`). Tell the user it is per clone."
        )
    _, idx = git(d, "ls-files", "-s", "--", hdir)
    modes = {
        line.split("\t", 1)[1]: line.split()[0]
        for line in idx.splitlines()
        if "\t" in line
    }
    hd = os.path.join(d, hdir)
    for f in sorted(os.listdir(hd)) if os.path.isdir(hd) else []:
        p = os.path.join(hd, f)
        if not os.path.isfile(p) or f.endswith(".sample"):
            continue
        checked += 1
        rel = os.path.relpath(p, d)
        exe = bool(os.stat(p).st_mode & stat.S_IXUSR)
        im = modes.get(rel, "untracked")
        print(f"  {rel}: worktree {'755' if exe else '644'}, index {im}")
        if not exe or im == "100644":
            find(
                f"{rel} is not executable ({'worktree' if not exe else 'index ' + im}): git skips it silently. "
                f"chmod +x fixes this clone; other clones get it only once the mode is committed (`git add` records it where core.fileMode is true, else `git update-index --chmod=+x {rel}`)."
            )
        body = open(p, encoding="utf-8", errors="replace").read()
        m = re.search(
            r"\$\{?([A-Z][A-Z0-9_]*(CONFIRM|SKIP|BYPASS|FORCE)[A-Z0-9_]*)", body
        )
        if m:
            find(
                f"{rel} is bypassed by {m.group(1)}: an agent can set that variable itself, so this hook is not a wall "
                "against an agent; the harness hook is."
            )

    print("== .gitignore against what the generator writes")
    want = WRITES.get(harness, [])
    for rel in want:
        checked += 1
    if want:
        r = subprocess.run(
            ["git", "-C", d, "check-ignore", "-v", "--no-index", *want],
            capture_output=True,
            text=True,
        )
        for line in r.stdout.splitlines():
            src, path = line.split("\t", 1)
            find(
                f"{path} would be ignored ({src}): a teammate's clone would not get it. Adjust .gitignore and tell the user."
            )

    print(f"audit: {checked} item(s) checked, {len(findings)} finding(s)")
    return 1 if checked == 0 else 0


# ---------------------------------------------------------------- extend
def extend(d, harness):
    cfgs = {"cursor": ".cursor/hooks.json", "codex": ".codex/hooks.json"}
    if harness in cfgs and not os.path.isfile(os.path.join(d, cfgs[harness])):
        raise SystemExit(f"extend: no {cfgs[harness]}; run brg-harness {harness} first")
    entries = settings_entries(d) or []
    extra = [
        ("deny", f"make {t}")
        for t, _ in hidden_targets(d, entries)
        if not any(k == "deny" and w.split()[:2] == ["make", t] for k, w in entries)
    ]
    rows = entries + extra
    if not rows:
        print(
            "extend: 0 entries: no shell denies in .claude/settings.json and no make target hides a deploy",
            file=sys.stderr,
        )
        return 1
    os.makedirs(os.path.join(d, ".bearing", "hooks"), exist_ok=True)
    with open(os.path.join(d, ".bearing", "settings-denies.txt"), "w") as f:
        f.write(
            "# Derived from .claude/settings.json (and make targets whose recipe deploys) by harness-setup.\n"
            "# kind<TAB>words. Regenerate after changing the Claude settings.\n"
        )
        for k, w in rows:
            f.write(f"{k}\t{w}\n")
    hook = os.path.join(d, ".bearing", "hooks", "settings-deny.sh")
    shutil.copyfile(TEMPLATE, hook)
    os.chmod(hook, 0o755)
    mode = {
        "cursor": "cursor",
        "gemini": "gemini",
        "copilot": "copilot",
        "cline": "cline",
    }.get(harness, "exit2")
    wrapper = os.path.join(d, ".bearing", "hooks", f"settings-deny-{harness}.sh")
    with open(wrapper, "w") as f:
        f.write(
            f'#!/usr/bin/env bash\nexec bash "$(dirname "$0")/settings-deny.sh" {mode}\n'
        )
    os.chmod(wrapper, 0o755)
    cmd = f"./.bearing/hooks/settings-deny-{harness}.sh"
    where = register(d, harness, cmd)
    if harness == "codex":
        with open(os.path.join(d, ".codex", "rules", "settings.rules"), "w") as f:
            f.write(
                "# Codex execpolicy rules from .claude/settings.json (harness-setup). Prefix rules miss\n"
                "# wrapped forms (bash -lc, git -C); the PreToolUse hooks are the control.\n"
            )
            for k, w in rows:
                if k in ("deny", "ask"):
                    pat = ", ".join(json.dumps(x) for x in w.split())
                    dec = "forbidden" if k == "deny" else "prompt"
                    f.write(
                        f'prefix_rule(pattern = [{pat}], decision = "{dec}", justification = "denied in .claude/settings.json")\n'
                    )
    n = {k: sum(1 for r in rows if r[0] == k) for k in ("deny", "ask", "path")}
    print(
        f"extend: {len(rows)} entries ({n['deny']} deny, {n['ask']} ask, {n['path']} path; {len(extra)} from make targets) "
        f"in .bearing/settings-denies.txt; {where}"
    )
    return 0


def register(d, harness, cmd):
    if harness == "cursor":
        p = os.path.join(d, ".cursor", "hooks.json")
        cfg = json.load(open(p))
        lst = cfg.setdefault("hooks", {}).setdefault("beforeShellExecution", [])
        if not any(h.get("command") == cmd for h in lst):
            lst.append({"command": cmd, "timeout": 10})
    elif harness == "codex":
        p = os.path.join(d, ".codex", "hooks.json")
        cfg = json.load(open(p))
        lst = cfg.setdefault("hooks", {}).setdefault("PreToolUse", [])
        if not any(x.get("command") == cmd for e in lst for x in e.get("hooks", [])):
            lst.append(
                {
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": cmd, "timeout": 10}],
                }
            )
    else:
        return f"register {cmd} as a second shell hook in {harness}'s config yourself (see the matrix)"
    with open(p, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    return f"registered in {os.path.relpath(p, d)} (brg-harness will now report this file as a conflict on a rerun; keep this version)"


# ---------------------------------------------------------------- check
def shell_hooks(d, harness):
    if harness == "cursor":
        cfg = json.load(open(os.path.join(d, ".cursor", "hooks.json")))
        return [
            h["command"] for h in cfg.get("hooks", {}).get("beforeShellExecution", [])
        ]
    if harness == "codex":
        cfg = json.load(open(os.path.join(d, ".codex", "hooks.json")))
        return [
            x["command"]
            for e in cfg.get("hooks", {}).get("PreToolUse", [])
            if re.search(e.get("matcher", ".*"), "Bash")
            for x in e.get("hooks", [])
        ]
    raise SystemExit(
        f"check: {harness} is not scripted here; feed its event JSON to its hook by hand (see the matrix)"
    )


def event(harness, c):
    if c is None:
        return "not json {"
    if c == "":
        return json.dumps({"hook_event_name": "x"})
    if harness == "cursor":
        return json.dumps(
            {"hook_event_name": "beforeShellExecution", "command": c, "cwd": "."}
        )
    return json.dumps(
        {
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": c},
        }
    )


def verdict(d, hooks, harness, c):
    worst = "allow"
    for h in hooks:
        r = subprocess.run(
            h,
            shell=True,
            cwd=d,
            input=event(harness, c),
            capture_output=True,
            text=True,
            timeout=30,
        )
        v = "allow"
        if r.returncode == 2:
            v = "deny"
        else:
            try:
                o = json.loads(r.stdout or "{}")
                v = o.get("permission") or (
                    "deny" if o.get("decision") in ("deny", "block") else "allow"
                )
            except ValueError:
                v = "deny" if r.returncode else "allow"
        if r.returncode not in (0, 2):
            v = "error"
        rank = {"allow": 0, "ask": 1, "error": 2, "deny": 3}
        worst = v if rank.get(v, 3) > rank[worst] else worst
    return worst


def samples(kind, words):
    w = words.split()
    tail = {
        "git push": " origin main",
        "kubectl": " get pods",
        "gh pr merge": " 12",
    }.get(words, "")
    base = words + tail
    out = [base, f"bash -lc '{base}'", f"FOO=1 {base}"]
    if w[0] == "git":
        out.append("git -C . " + " ".join(w[1:]) + tail)
    if w[0] == "make":
        out.append("make -C . " + " ".join(w[1:]))
    if kind == "path":
        out = [f"cat {words}", f"cat ./{words}", f"grep -r KEY {words}"]
    return out


def check(d, harness):
    hooks = shell_hooks(d, harness)
    if not hooks:
        print(f"check: {harness} has no shell hook configured", file=sys.stderr)
        return 1
    entries = settings_entries(d) or []
    entries += [("deny", f"make {t}") for t, _ in hidden_targets(d, entries)]
    entries += [("deny", "git push")]
    cases = []
    for k, w in dict.fromkeys(entries):
        for c in samples(k, w):
            cases.append((c, {"ask": ("ask", "deny")}.get(k, ("deny",)), f"{k} {w}"))
    ok = [
        "git status",
        "make check" if "check" in make_targets(d) else "ls",
        "go test ./..." if os.path.isfile(os.path.join(d, "go.mod")) else "git diff",
    ]
    cases += [(c, ("allow",), "ordinary work") for c in ok]
    cases += [
        (None, ("deny",), "fail closed: not JSON"),
        ("", ("deny",), "fail closed: no command"),
    ]
    gaps = 0
    print(f"shell hooks ({harness}): " + ", ".join(hooks))
    for c, want, why in cases:
        v = verdict(d, hooks, harness, c)
        good = v in want
        gaps += not good
        print(
            f"  {'ok ' if good else 'GAP'} {v:5} {'<unreadable>' if c is None else (c or '<no command>'):45} {why}"
            + ("" if good else f" (expected {'/'.join(want)})")
        )
    print(f"check: {len(cases)} command(s) checked, {gaps} gap(s)")
    return 1 if gaps or not cases else 0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("cmd", choices=["audit", "extend", "check"])
    ap.add_argument("harness", choices=sorted(WRITES))
    ap.add_argument("--dir", default=".")
    a = ap.parse_args()
    d = os.path.abspath(a.dir)
    return {"audit": audit, "extend": extend, "check": check}[a.cmd](d, a.harness)


if __name__ == "__main__":
    sys.exit(main())
